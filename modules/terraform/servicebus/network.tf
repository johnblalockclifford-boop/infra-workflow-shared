# ---------------------------------------------------------------------------
# Existing network resources — always REFERENCED, never created here.
# ---------------------------------------------------------------------------

# Application VNet + subnet that host the private endpoints. Names default to the
# prod network for prod and the shared development network for every other env
# (see local.default_network in main.tf); override via the var.* inputs.
data "azurerm_virtual_network" "this" {
  name                = local.virtual_network_name
  resource_group_name = local.virtual_network_resource_group_name
}

data "azurerm_subnet" "private_link" {
  name                 = local.private_link_subnet_name
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = data.azurerm_virtual_network.this.resource_group_name
}

# Shared, hub-managed private DNS zones — always REFERENCED, never created.
#
# Every privatelink zone lives in the FTDC4-Production subscription, in the
# FTDC4-Network-P resource group. This is invariant: there is NO per-environment
# DNS deployment, so dev and prod both read the exact same zones. That is why
# these lookups use the azurerm.ftdc4-production alias (and dns_resource_group_name
# defaults to FTDC4-Network-P) regardless of var.environment. Do not parameterize
# these per env. The network team owns the zones and their VNet links.
data "azurerm_private_dns_zone" "servicebus" {
  count               = var.private_endpoint_enabled && var.private_dns_integration_enabled ? 1 : 0
  provider            = azurerm.ftdc4-production
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.dns_resource_group_name
}

data "azurerm_private_dns_zone" "keyvault" {
  count               = var.private_endpoint_enabled && var.private_dns_integration_enabled ? 1 : 0
  provider            = azurerm.ftdc4-production
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.dns_resource_group_name
}
