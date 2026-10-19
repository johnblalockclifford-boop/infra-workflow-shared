# Key Vault - Local Admin Password
data "azurerm_key_vault" "this" {
  name                = "${var.data_center}-systemskeyvault1-${var.env_short}"
  resource_group_name = "${var.data_center}-Management-${var.env_short}"
}

data "azurerm_key_vault_secret" "this" {
  name         = "faithlocadm"
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_virtual_network" "this" {
  name                = "${var.data_center}-Development1-${var.env_short}"
  resource_group_name = "${var.data_center}-Network-${var.env_short}"
}

#Note/Reminder: Before calling data you may have use the 'data azurerm_virtual_network ' block to get the virtual network name and resource group name.
data "azurerm_subnet" "this" {
  name                 = "Compute"
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = data.azurerm_virtual_network.this.resource_group_name
}

# NIC
resource "azurerm_network_interface" "this" {
  name                = "${var.data_center}-${var.use_case}-${var.env_short}-ni"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Data Disk
resource "azurerm_managed_disk" "this" {
  name                 = "${var.data_center}-${var.use_case}-${var.env_short}-datadisk"
  location             = var.resource_group.location
  resource_group_name  = var.resource_group.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "64"

  tags = {
    CreatedBy        = "${var.createdby_tag}"
    OperationalOwner = "${var.operationalOwner_tag}"
    MaintainedBy     = "${var.maintainedBy_tag}"
    Asset            = "${var.asset_tag}"
    RequestedBy      = "${var.requestedBy_tag}"
    Environment      = "${var.environment_tag}"
  }
}

# Attach Data Disk to VM
resource "azurerm_virtual_machine_data_disk_attachment" "this" {
  managed_disk_id    = azurerm_managed_disk.this.id
  virtual_machine_id = var.os == "windows" ? azurerm_windows_virtual_machine.this[0].id : azurerm_linux_virtual_machine.this[0].id
  lun                = "10"
  caching            = "ReadWrite"
}