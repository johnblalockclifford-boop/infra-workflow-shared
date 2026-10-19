# DNS
data "azurerm_private_dns_zone" "azurewebsites" {
  provider            = azurerm.ftdc4-production
  name                = "privatelink.azurewebsites.net"
  resource_group_name = "FTDC4-Network-P"
}

data "azurerm_private_dns_zone" "storageaccountblob" {
  provider            = azurerm.ftdc4-production
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "FTDC4-Network-P"
}

data "azurerm_private_dns_zone" "keyvault" {
  provider            = azurerm.ftdc4-production
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = "FTDC4-Network-P"
}

data "azurerm_dns_zone" "custom" {
  count               = local.deploy_custom_domain ? 1 : 0
  provider            = azurerm.ftdc4-production
  name                = local.custom_base_domain
  resource_group_name = "FTDC4-PublicDNS-P"
}

# VNET
data "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  resource_group_name = var.virtual_network_resource_group_name
}

data "azurerm_subnet" "private_link_subnet" {
  name                 = var.private_link_subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_virtual_network.vnet.resource_group_name
}

data "azurerm_subnet" "vnet_integration" {
  name                 = var.vnet_integration_subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_virtual_network.vnet.resource_group_name
}
