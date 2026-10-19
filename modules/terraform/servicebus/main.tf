data "azurerm_client_config" "current" {}

# Resource group that hosts the Service Bus / Key Vault resources.
data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  # Environment codes follow the FTI Resource Naming Standard §2.3 (final list):
  #   p prod/production, d dev/development, s stage, t test, u uat, q qa,
  #   x sbx/sandbox. The short code is what appears in resource names; callers may
  #   pass the short, medium or long spelling (case-insensitive) and each resolves
  #   to the same name. There are deliberately NO other aliases — np, nonprod and
  #   stg are not standard environments, and uat/qa are distinct environments, not
  #   synonyms for test/stage.
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

  # Long form of the environment for the auto-injected Environment tag
  # (standard §2.3, "Long (tags/display)" column).
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

  # Location codes (standard §2.2), derived from the resource group's region so the
  # name always matches where the resources actually are. Add a new region to the
  # standard (§2.2) before adding it here.
  location_code_map = {
    northcentralus = "ncus"
    centralus      = "cus"
    eastus2        = "eus2"
  }
  location = try(local.location_code_map[lower(replace(data.azurerm_resource_group.this.location, " ", ""))], "unregistered")

  # Default network placement. Prod is isolated on the production network; every
  # non-prod environment (d, s, t, u, q, x) shares the
  # development network so production stays truly production. Each value is independently
  # overridable via the matching var.* input (e.g. to place a new env on its own
  # VNet later) — coalesce falls back to these defaults only when the var is null.
  #
  # CASING IS LOAD-BEARING — match the network RG exactly as Azure spells it
  # (FTDC4-Network-{D,P}, same casing as dns_resource_group_name). Azure treats
  # resource IDs as case-insensitive, but Terraform diffs subnet_id as a plain
  # string, and subnet_id is ForceNew on azurerm_private_endpoint. A casing-only
  # change here therefore plans a destroy/recreate of BOTH private endpoints,
  # which reassigns their private IPs and drops connectivity to the namespace and
  # vault. Do not "normalize" these to lowercase.
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

  # Merge a canonical Environment tag (derived from the normalized env) with the
  # caller's tags. Caller-supplied keys win, so the default is overridable.
  tags = merge({ Environment = local.env_long }, var.tags)

  # Naming (standard §1): {site}-{base}-{type}-{location}-{env}. Child resources
  # take the parent's {site}-{base}-{type} followed by their own type.
  #
  # Constraint handling (§5): where a name has a length limit, base is the ONLY
  # segment that is shortened — first by swapping in name_short, then by
  # truncating. Site, type, location and env are always preserved in full.
  site_lc    = lower(var.site)
  suffix     = "${local.location}-${local.env}"
  base_short = coalesce(var.name_short, var.base_name)

  # Namespace: 6–50 chars, letters/digits/hyphens, globally unique.
  # Fixed overhead: site + "-" + "-sbns-" (6) + suffix.
  sbns_base_max = 50 - length(local.site_lc) - 1 - 6 - length(local.suffix)
  sbns_base     = trimsuffix(substr(local.base_short, 0, max(0, local.sbns_base_max)), "-")
  name_prefix   = "${local.site_lc}-${local.sbns_base}"

  namespace_name        = "${local.name_prefix}-sbns-${local.suffix}"
  private_endpoint_name = "${local.name_prefix}-sbns-pep-${local.suffix}"
  private_endpoint_psc  = "${local.name_prefix}-sbns-psc-${local.suffix}"
  private_endpoint_dzg  = "${local.name_prefix}-sbns-dzg-${local.suffix}"
  uami_name             = "${local.name_prefix}-id-${local.suffix}"

  # Key Vault: 3–24 chars, letters/digits/hyphens, globally unique.
  # Fixed overhead: site + "-" + "-kv-" (4) + suffix.
  kv_base_max    = 24 - length(local.site_lc) - 1 - 4 - length(local.suffix)
  kv_base        = trimsuffix(substr(local.base_short, 0, max(0, local.kv_base_max)), "-")
  kv_prefix      = "${local.site_lc}-${local.kv_base}"
  key_vault_name = "${local.kv_prefix}-kv-${local.suffix}"
  kv_pe_name     = "${local.kv_prefix}-kv-pep-${local.suffix}"
  kv_pe_psc      = "${local.kv_prefix}-kv-psc-${local.suffix}"
  kv_pe_dzg      = "${local.kv_prefix}-kv-dzg-${local.suffix}"
}

# ---------------------------------------------------------------------------
# Service Bus namespace (private-only Premium)
# ---------------------------------------------------------------------------

resource "azurerm_servicebus_namespace" "this" {
  name                          = local.namespace_name
  location                      = data.azurerm_resource_group.this.location
  resource_group_name           = data.azurerm_resource_group.this.name
  sku                           = var.sku
  capacity                      = var.sku == "Premium" ? var.capacity : null
  premium_messaging_partitions  = var.sku == "Premium" ? var.premium_messaging_partitions : null
  public_network_access_enabled = var.public_network_access_enabled

  tags = local.tags

  lifecycle {
    precondition {
      condition     = local.location != "unregistered"
      error_message = "Resource group region \"${data.azurerm_resource_group.this.location}\" has no location code. Add it to the naming standard (§2.2) and to local.location_code_map before first use."
    }
  }
}

# NOTE: Queues, topics and subscriptions are intentionally NOT created here —
# entity provisioning is owned by the development teams that consume the
# namespace. This module provisions the namespace and its access plumbing only.

# ---------------------------------------------------------------------------
# User-Assigned Managed Identity for Azure App Service data-plane auth
#
# CONSUMER: the Azure App Service(s) that talk to this namespace (deployed by the
# shared linux_app_service_internal module). The app is assigned this identity and
# uses DefaultAzureCredential; the module exposes uami_client_id / uami_principal_id
# outputs, and the app deployment wires uami_client_id into the App Service's
# identity block and AZURE_CLIENT_ID so the SDK resolves the right identity.
#
# WHY user-assigned (not system-assigned):
#   - The identity and its RBAC role assignments exist independently of, and before,
#     the App Service — so there's no chicken-and-egg on first deploy, and the app
#     can be destroyed/recreated without re-granting Service Bus / Key Vault roles.
#   - One identity can be shared across multiple apps / slots / instances that use
#     the same namespace, instead of granting roles per system identity.
# Set uami_enabled = false to skip it (e.g. when only on-prem SAS consumers exist).
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "this" {
  count               = var.uami_enabled ? 1 : 0
  name                = local.uami_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "uami_sender" {
  count                = var.uami_enabled ? 1 : 0
  scope                = azurerm_servicebus_namespace.this.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_user_assigned_identity.this[0].principal_id
}

resource "azurerm_role_assignment" "uami_receiver" {
  count                = var.uami_enabled ? 1 : 0
  scope                = azurerm_servicebus_namespace.this.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.this[0].principal_id
}

# ---------------------------------------------------------------------------
# Namespace-level SAS authorization rules for on-prem (legacy) apps
# ---------------------------------------------------------------------------

resource "azurerm_servicebus_namespace_authorization_rule" "sas" {
  for_each = var.onprem_sas_apps

  name         = "${local.name_prefix}-sas-${each.key}-${local.suffix}"
  namespace_id = azurerm_servicebus_namespace.this.id

  listen = each.value.listen
  send   = each.value.send
  manage = each.value.manage
}

# ---------------------------------------------------------------------------
# Geo-Disaster Recovery (active/passive) — PROD ONLY
#
# Pairs this (primary) namespace with a partner Premium namespace in the paired
# region behind an alias, so clients fail over transparently by connecting to
# the alias. This is metadata-only replication (entities/config), not message
# data — see the Azure Geo-DR docs.
#
# Gated behind geo_disaster_recovery_enabled (default false) so dev deploys
# without it and is never delayed by it. Enable it only in p.tfvars once the
# partner namespace exists in the paired region.
# ---------------------------------------------------------------------------

resource "azurerm_servicebus_namespace_disaster_recovery_config" "this" {
  count                = var.geo_disaster_recovery_enabled ? 1 : 0
  name                 = coalesce(var.geo_dr_alias_name, "${local.name_prefix}-geodr-${local.suffix}")
  primary_namespace_id = azurerm_servicebus_namespace.this.id
  partner_namespace_id = var.geo_dr_partner_namespace_id

  lifecycle {
    precondition {
      condition     = var.geo_dr_partner_namespace_id != null
      error_message = "geo_dr_partner_namespace_id must be set when geo_disaster_recovery_enabled is true."
    }
  }
}

# ---------------------------------------------------------------------------
# Key Vault — one per environment, private-endpoint only.
#
# Public network access is disabled and the default network ACL is Deny, so the
# vault is reachable only through its private endpoint (and any CIDRs explicitly
# allowlisted via key_vault_network_acls_ip_rules). Because the Terraform runner
# must reach the data plane to WRITE the on-prem SAS secrets, run apply from a
# host on the VNet / over the VPN, or allowlist the runner's egress IP. This
# only matters when onprem_sas_apps is non-empty.
# ---------------------------------------------------------------------------

resource "azurerm_key_vault" "this" {
  count                         = var.key_vault_enabled ? 1 : 0
  name                          = local.key_vault_name
  location                      = data.azurerm_resource_group.this.location
  resource_group_name           = data.azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = var.key_vault_sku_name
  soft_delete_retention_days    = var.key_vault_soft_delete_days
  purge_protection_enabled      = var.key_vault_purge_protection_enabled
  public_network_access_enabled = false
  rbac_authorization_enabled    = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.key_vault_network_acls_ip_rules
  }

  tags = local.tags

  # Azure Key Vault names are globally scoped and limited to 3–24 characters,
  # alphanumerics and hyphens only, starting with a letter, ending with a letter
  # or digit, and no consecutive hyphens. base is truncated in locals (standard §5)
  # so the name fits; these guards catch what truncation cannot fix (an over-long
  # site, or an invalid base) with a clear message rather than letting Azure reject
  # the apply mid-flight.
  lifecycle {
    precondition {
      condition     = length(local.key_vault_name) <= 24
      error_message = "Key Vault name \"${local.key_vault_name}\" is ${length(local.key_vault_name)} chars; the Azure limit is 24 even after truncating base_name. Shorten site or set name_short."
    }
    precondition {
      condition     = can(regex("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", local.key_vault_name))
      error_message = "Key Vault name \"${local.key_vault_name}\" is invalid: use only lowercase letters, digits and single hyphens, starting with a letter (no leading/trailing/consecutive hyphens)."
    }
  }
}

# Grant the deploying identity data-plane rights so Terraform can write the SAS
# secrets below. Only needed when there are on-prem SAS apps.
resource "azurerm_role_assignment" "runner_secrets_officer" {
  count                = var.key_vault_enabled && length(var.onprem_sas_apps) > 0 ? 1 : 0
  scope                = azurerm_key_vault.this[0].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Grant the consuming UAMI read access to the SAS secrets. Mirrors the shared
# linux_app_service_internal module, where the App Service's managed identity is
# granted "Key Vault Secrets User" so the app can resolve @Microsoft.KeyVault(...)
# references at runtime. Here the module-created UAMI is that consuming identity.
resource "azurerm_role_assignment" "uami_secrets_user" {
  count                = var.key_vault_enabled && var.uami_enabled ? 1 : 0
  scope                = azurerm_key_vault.this[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.this[0].principal_id
}

resource "azurerm_private_endpoint" "keyvault" {
  count               = var.key_vault_enabled && var.private_endpoint_enabled ? 1 : 0
  name                = local.kv_pe_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = data.azurerm_subnet.private_link.id

  private_service_connection {
    name                           = local.kv_pe_psc
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.this[0].id
    subresource_names              = ["vault"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_integration_enabled ? [1] : []
    content {
      name                 = local.kv_pe_dzg
      private_dns_zone_ids = [data.azurerm_private_dns_zone.keyvault[0].id]
    }
  }

  tags = local.tags
}

# Wait for the Key Vault private endpoint's DNS record to propagate (Infoblox →
# Azure DNS Private Resolver) before writing secrets to the data plane. Without
# this, a first-time apply resolves the vault hostname to its public IP before
# the private record is cached and the write fails with 403 ForbiddenByConnection.
# Matches the pattern used by the shared linux_app_service_internal module.
resource "time_sleep" "keyvault_pe_dns_propagation" {
  count           = var.key_vault_enabled && var.private_endpoint_enabled && length(var.onprem_sas_apps) > 0 ? 1 : 0
  create_duration = "60s"
  depends_on      = [azurerm_private_endpoint.keyvault]
}

# Store on-prem SAS connection strings as Key Vault secrets.
resource "azurerm_key_vault_secret" "sas" {
  for_each = var.key_vault_enabled ? var.onprem_sas_apps : {}

  name         = "${local.name_prefix}-sas-${each.key}-${local.suffix}"
  value        = azurerm_servicebus_namespace_authorization_rule.sas[each.key].primary_connection_string
  key_vault_id = azurerm_key_vault.this[0].id

  tags = local.tags

  depends_on = [
    azurerm_role_assignment.runner_secrets_officer,
    azurerm_private_endpoint.keyvault,
    time_sleep.keyvault_pe_dns_propagation,
  ]
}

# ---------------------------------------------------------------------------
# Service Bus private endpoint
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "servicebus" {
  count               = var.private_endpoint_enabled ? 1 : 0
  name                = local.private_endpoint_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = data.azurerm_subnet.private_link.id

  private_service_connection {
    name                           = local.private_endpoint_psc
    is_manual_connection           = false
    private_connection_resource_id = azurerm_servicebus_namespace.this.id
    subresource_names              = ["namespace"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_integration_enabled ? [1] : []
    content {
      name                 = local.private_endpoint_dzg
      private_dns_zone_ids = [data.azurerm_private_dns_zone.servicebus[0].id]
    }
  }

  tags = local.tags
}
