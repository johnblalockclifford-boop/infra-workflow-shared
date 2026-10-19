output "vm_name" {
  value = var.os == "windows" ? azurerm_windows_virtual_machine.this[0].name : azurerm_linux_virtual_machine.this[0].name
}

output "vm_ip" {
  value = azurerm_network_interface.this.private_ip_address
}

# Grant this to a role rather than putting credentials on the host, e.g.
#   resource "azurerm_role_assignment" "acr_pull" {
#     scope                = azurerm_container_registry.this.id
#     role_definition_name = "AcrPull"
#     principal_id         = module.my_vm.vm_principal_id
#   }
output "vm_principal_id" {
  description = "Object ID of the VM's system-assigned managed identity."

  # Splat rather than a conditional with [0]. Terraform evaluates both branches
  # of a conditional, so the inactive OS - which has count = 0 - is indexed out
  # of range and the whole expression collapses to null. A consumer then sees
  # "principal_id is required, but no definition was found" at validate time,
  # which points at their role assignment rather than at this output.
  #
  # A splat over a count = 0 resource yields [], so concat leaves exactly one
  # element and one() unwraps it.
  value = one(concat(
    azurerm_windows_virtual_machine.this[*].identity[0].principal_id,
    azurerm_linux_virtual_machine.this[*].identity[0].principal_id,
  ))
}