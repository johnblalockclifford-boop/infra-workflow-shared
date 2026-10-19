# Resource group that holds the SQL server and its private endpoint.
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

# The group that administers the server.
data "azuread_group" "administrators" {
  display_name     = var.administrator_group_name
  security_enabled = true
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

  # Default network: the production network for prod, the shared development
  # network for every other environment. Each var.* input overrides one value.
  # Casing matters: see the virtual_network_resource_group_name description.
  is_prod = local.env == "p"
  default_network = local.is_prod ? {
    virtual_network_name                = "FTDC4-Production1-P"
    virtual_network_resource_group_name = "FTDC4-Network-P"
    private_link_subnet_name            = "Application"
    } : {
    virtual_network_name                = "FTDC4-Development1-D"
    virtual_network_resource_group_name = "FTDC4-Network-D"
    private_link_subnet_name            = "Dev-Application"
  }
  virtual_network_name                = coalesce(var.virtual_network_name, local.default_network.virtual_network_name)
  virtual_network_resource_group_name = coalesce(var.virtual_network_resource_group_name, local.default_network.virtual_network_resource_group_name)
  private_link_subnet_name            = coalesce(var.private_link_subnet_name, local.default_network.private_link_subnet_name)

  # The caller's tags win over the Environment tag.
  tags = merge({ Environment = local.env_long }, var.tags)


  # Naming (standard §1): {site}-{base}-{type}-{location}-{env}, type sql.
  #
  # A server name is 1 to 63 characters, lowercase letters, digits and hyphens,
  # and globally unique (<name>.database.windows.net). Only base is shortened
  # to fit (standard §5).
  site_lc     = lower(var.site)
  suffix      = "${local.location}-${local.env}"
  server_max  = 63 - length(local.site_lc) - 1 - 5 - length(local.suffix)
  server_base = trimsuffix(substr(var.base_name, 0, max(0, local.server_max)), "-")
  prefix      = "${local.site_lc}-${local.server_base}-sql"
  server_name = "${local.prefix}-${local.suffix}"
  pe_name     = "${local.prefix}-pep-${local.suffix}"
  pe_psc      = "${local.prefix}-psc-${local.suffix}"
  pe_dzg      = "${local.prefix}-dzg-${local.suffix}"
}

# ---------------------------------------------------------------------------
# SQL server: private only, Entra ID authentication only. Databases are the
# sql_database_internal module's: one module call per database.
# ---------------------------------------------------------------------------

resource "azurerm_mssql_server" "this" {
  name                          = local.server_name
  resource_group_name           = data.azurerm_resource_group.this.name
  location                      = data.azurerm_resource_group.this.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username              = data.azuread_group.administrators.display_name
    object_id                   = data.azuread_group.administrators.object_id
    azuread_authentication_only = true
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = local.location != "unregistered"
      error_message = "Resource group region \"${data.azurerm_resource_group.this.location}\" has no location code. Add it to the naming standard (§2.2) and to local.location_code_map before first use."
    }
    precondition {
      condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", local.server_name))
      error_message = "SQL server name \"${local.server_name}\" is invalid: Azure allows 1 to 63 lowercase letters, digits and hyphens, not starting or ending with a hyphen."
    }
  }
}

# ---------------------------------------------------------------------------
# SQL server private endpoint
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "sql" {
  count               = var.private_endpoint_enabled ? 1 : 0
  name                = local.pe_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = data.azurerm_subnet.private_link.id

  private_service_connection {
    name                           = local.pe_psc
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names              = ["sqlServer"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_integration_enabled ? [1] : []
    content {
      name                 = local.pe_dzg
      private_dns_zone_ids = [data.azurerm_private_dns_zone.sql[0].id]
    }
  }

  tags = local.tags
}
