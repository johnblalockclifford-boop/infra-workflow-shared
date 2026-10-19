## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_linux_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_managed_disk.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_disk) | resource |
| [azurerm_network_interface.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_virtual_machine_data_disk_attachment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_data_disk_attachment) | resource |
| [azurerm_windows_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) | resource |
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_asset_tag"></a> [asset\_tag](#input\_asset\_tag) | The overarching asset this resource supports (e.g., application name, hardware, device) | `string` | `"asset_name"` | no |
| <a name="input_createdby_tag"></a> [createdby\_tag](#input\_createdby\_tag) | If manual - the person who created a resource. If automated- the automation tool used to create resource | `string` | `"INF Terraform"` | no |
| <a name="input_data_center"></a> [data\_center](#input\_data\_center) | Data Center/site | `string` | `"ftdc4"` | no |
| <a name="input_env_short"></a> [env\_short](#input\_env\_short) | Short environment name | `string` | `"d"` | no |
| <a name="input_environment_tag"></a> [environment\_tag](#input\_environment\_tag) | The environment where the resource resides (e.g., Production, Staging, Development) | `string` | `"Development"` | no |
| <a name="input_maintainedBy_tag"></a> [maintainedBy\_tag](#input\_maintainedBy\_tag) | Department responsible for resource maintenance and accountability (e.g., Maintenance) | `string` | `"MaintainedBy"` | no |
| <a name="input_operationalOwner_tag"></a> [operationalOwner\_tag](#input\_operationalOwner\_tag) | Department that utilizes or requested the resource (e.g., Operations) | `string` | `"OperationalOwner"` | no |
| <a name="input_os"></a> [os](#input\_os) | Operating System | `any` | n/a | yes |
| <a name="input_requestedBy_tag"></a> [requestedBy\_tag](#input\_requestedBy\_tag) | The user who requested the resource | `string` | `"RequestedBy"` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Resource Group | `any` | n/a | yes |
| <a name="input_use_case"></a> [use\_case](#input\_use\_case) | Use Case | `any` | n/a | yes |
| <a name="input_vm_image_id"></a> [vm\_image\_id](#input\_vm\_image\_id) | VM Image ID | `any` | n/a | yes |
| <a name="input_vm_os_disk_size"></a> [vm\_os\_disk\_size](#input\_vm\_os\_disk\_size) | OS Disk Size | `string` | `"64"` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Size of the VM | `string` | `"Standard_b2ms"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_vm_ip"></a> [vm\_ip](#output\_vm\_ip) | n/a |
| <a name="output_vm_name"></a> [vm\_name](#output\_vm\_name) | n/a |
