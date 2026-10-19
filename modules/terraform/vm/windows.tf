# Windows Virtual Machine Definition
resource "azurerm_windows_virtual_machine" "this" {
  count                                                  = var.os == "windows" ? 1 : 0
  name                                                   = "${var.data_center}-${var.use_case}-${var.env_short}"
  location                                               = var.resource_group.location
  resource_group_name                                    = var.resource_group.name
  network_interface_ids                                  = [azurerm_network_interface.this.id]
  size                                                   = var.vm_size
  admin_username                                         = "faithlocadm"
  admin_password                                         = data.azurerm_key_vault_secret.this.value
  patch_mode                                             = "AutomaticByPlatform"
  patch_assessment_mode                                  = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule_enabled = true
  automatic_updates_enabled                              = false
  license_type                                           = "Windows_Server"

  # Use vm_image_id if provided, otherwise use source_image_reference
  source_image_id = var.vm_image_id

  dynamic "source_image_reference" {
    for_each = var.vm_image_id == null ? [1] : []
    content {
      publisher = local.source_image_reference.publisher
      offer     = local.source_image_reference.offer
      sku       = local.source_image_reference.sku
      version   = local.source_image_reference.version
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.vm_os_disk_size
  }

  # Lets callers grant the VM itself a role - AcrPull to pull container images,
  # or Key Vault access - instead of placing credentials on the host. Adding an
  # identity to an existing VM is an in-place update, not a replacement.
  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  tags = {
    CreatedBy        = "${var.createdby_tag}"
    OperationalOwner = "${var.operationalOwner_tag}"
    MaintainedBy     = "${var.maintainedBy_tag}"
    Asset            = "${var.asset_tag}"
    RequestedBy      = "${var.requestedBy_tag}"
    Environment      = "${var.environment_tag}"
  }
}
