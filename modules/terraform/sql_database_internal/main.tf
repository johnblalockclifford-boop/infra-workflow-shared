# Resource group that holds the server, read for its region only.
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  # Environment codes of the FTI Resource Naming Standard §2.3. Each spelling
  # maps to the short code used in names. The same map as the servicebus module.
  env_short_map = {
    p           = "p"
    prod        = "p"
    production  = "p"
    d           = "d"
    dev         = "d"
    development = "d"
    s           = "s"
    stage       = "s"
    t           = "t"
    test        = "t"
    u           = "u"
    uat         = "u"
    q           = "q"
    qa          = "q"
    x           = "x"
    sbx         = "x"
    sandbox     = "x"
  }
  env = local.env_short_map[lower(var.environment)]

  # Long form of the environment for the Environment tag (standard §2.3).
  env_long_map = {
    p = "Production"
    d = "Development"
    s = "Stage"
    t = "Test"
    u = "UAT"
    q = "QA"
    x = "Sandbox"
  }
  env_long = local.env_long_map[local.env]

  # Location codes (standard §2.2), read from the resource group's region. A
  # region missing here fails the plan (see the precondition below).
  location_code_map = {
    northcentralus = "ncus"
    centralus      = "cus"
    eastus2        = "eus2"
  }
  location = try(local.location_code_map[lower(replace(data.azurerm_resource_group.this.location, " ", ""))], "unregistered")

  # The caller's tags win over the Environment tag.
  tags = merge({ Environment = local.env_long }, var.tags)

  # Naming (standard §1): {site}-{base}-{type}-{location}-{env}, type sqldb,
  # with the database's own name after the type, as the servicebus module
  # names its SAS rules. A database name is up to 128 characters.
  site_lc       = lower(var.site)
  database_name = "${local.site_lc}-${var.base_name}-sqldb-${var.database_short_name}-${local.location}-${local.env}"

  serverless = startswith(var.sku_name, "GP_S_")
}

# ---------------------------------------------------------------------------
# Database
#
# Destroying it (removing the module call, or setting its environment to false
# in the caller's live map) deletes the database. Azure keeps a deleted
# database restorable for the short-term retention period while the server
# exists.
# ---------------------------------------------------------------------------

resource "azurerm_mssql_database" "this" {
  name                        = local.database_name
  server_id                   = var.server_id
  sku_name                    = var.sku_name
  max_size_gb                 = var.max_size_gb
  collation                   = var.collation
  zone_redundant              = false
  storage_account_type        = var.backup_storage_redundancy
  auto_pause_delay_in_minutes = local.serverless ? var.auto_pause_delay_in_minutes : null
  min_capacity                = local.serverless ? var.min_capacity : null

  short_term_retention_policy {
    retention_days = var.short_term_retention_days
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = local.location != "unregistered"
      error_message = "Resource group region \"${data.azurerm_resource_group.this.location}\" has no location code. Add it to the naming standard (§2.2) and to local.location_code_map before first use."
    }
    precondition {
      condition     = length(local.database_name) <= 128
      error_message = "Database name \"${local.database_name}\" is ${length(local.database_name)} characters; Azure allows 128."
    }
  }
}
