# ---------------------------------------------------------------------------
# Existing network resources. The module reads them and never creates them.
# ---------------------------------------------------------------------------

# The Virtual Network and subnet the private endpoint goes in. The names
# default by environment (local.default_network in main.tf).
data "azurerm_virtual_network" "this" {
  name                = local.virtual_network_name
  resource_group_name = local.virtual_network_resource_group_name
}

data "azurerm_subnet" "private_link" {
  name                 = local.private_link_subnet_name
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = data.azurerm_virtual_network.this.resource_group_name
}

# The shared privatelink zone. Every privatelink zone lives in the
# FTDC4-Production subscription, in FTDC4-Network-P, for every environment, so
# the lookup always goes through the azurerm.ftdc4-production alias. The network
# team owns the zone and its Virtual Network links.
data "azurerm_private_dns_zone" "sql" {
  count               = var.private_endpoint_enabled && var.private_dns_integration_enabled ? 1 : 0
  provider            = azurerm.ftdc4-production
  name                = "privatelink.database.windows.net"
  resource_group_name = var.dns_resource_group_name
}
