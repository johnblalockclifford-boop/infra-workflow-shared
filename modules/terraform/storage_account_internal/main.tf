# Resource group that holds the storage account and its private endpoint.
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

  # Naming (standard §1): {site}-{base}-{type}-{location}-{env}, type st.
  #
  # A storage account name is 3 to 24 characters, lowercase letters and digits
  # only, and globally unique, so it drops the hyphens. Only base is shortened
  # to fit (standard §5): first by using name_short in its place, then by
  # truncating. Site, st, location and env are kept in full.
  site_lc   = lower(var.site)
  suffix    = "${local.location}-${local.env}"
  sa_site   = replace(local.site_lc, "/[^a-z0-9]/", "")
  sa_base   = replace(coalesce(var.name_short, var.base_name), "-", "")
  sa_max    = 24 - length(local.sa_site) - 2 - length(local.location) - length(local.env)
  sa_name   = "${local.sa_site}${substr(local.sa_base, 0, max(0, local.sa_max))}st${local.location}${local.env}"
  pe_prefix = "${local.site_lc}-${var.base_name}-st"
  pe_name   = "${local.pe_prefix}-pep-${local.suffix}"
  pe_psc    = "${local.pe_prefix}-psc-${local.suffix}"
  pe_dzg    = "${local.pe_prefix}-dzg-${local.suffix}"
}

# ---------------------------------------------------------------------------
# Storage account: private only. Public network access is off, so the account
# is reachable only through the blob private endpoint below.
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "this" {
  name                            = local.sa_name
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = data.azurerm_resource_group.this.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = var.account_replication_type
  access_tier                     = var.access_tier
  public_network_access_enabled   = false
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = var.shared_access_key_enabled

  blob_properties {
    versioning_enabled = var.blob_versioning_enabled

    delete_retention_policy {
      days = var.blob_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.container_delete_retention_days
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = local.location != "unregistered"
      error_message = "Resource group region \"${data.azurerm_resource_group.this.location}\" has no location code. Add it to the naming standard (§2.2) and to local.location_code_map before first use."
    }
    precondition {
      condition     = can(regex("^[a-z0-9]{3,24}$", local.sa_name))
      error_message = "Storage account name \"${local.sa_name}\" is invalid: Azure allows 3 to 24 lowercase letters and digits. Shorten site."
    }
  }
}

# NOTE: Containers are not created here. The development team that uses the
# storage account owns its containers, as it owns the queues of a servicebus
# namespace.

# ---------------------------------------------------------------------------
# Blob private endpoint
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "blob" {
  count               = var.private_endpoint_enabled ? 1 : 0
  name                = local.pe_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = data.azurerm_subnet.private_link.id

  private_service_connection {
    name                           = local.pe_psc
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_integration_enabled ? [1] : []
    content {
      name                 = local.pe_dzg
      private_dns_zone_ids = [data.azurerm_private_dns_zone.blob[0].id]
    }
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Data-plane access through Entra ID
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "blob_data_contributor" {
  for_each             = var.blob_data_contributors
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "blob_data_reader" {
  for_each             = var.blob_data_readers
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value
}
