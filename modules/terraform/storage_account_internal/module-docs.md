<!-- This file mirrors the terraform-docs output used by the shared modules.
     Regenerate with: terraform-docs markdown ./modules/terraform/storage_account_internal -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.0 |
| <a name="provider_azurerm.ftdc4-production"></a> [azurerm.ftdc4-production](#provider\_azurerm.ftdc4-production) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_private_endpoint.blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_role_assignment.blob_data_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.blob_data_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_private_dns_zone.blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_subnet.private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_tier"></a> [access\_tier](#input\_access\_tier) | Default access tier for blobs: Hot or Cool. | `string` | `"Hot"` | no |
| <a name="input_account_replication_type"></a> [account\_replication\_type](#input\_account\_replication\_type) | Replication of the storage account: LRS, ZRS, GRS or GZRS. The read-access variants (RA-GRS, RA-GZRS) are not offered: reading the secondary privately needs a second private endpoint this module does not create. | `string` | `"LRS"` | no |
| <a name="input_base_name"></a> [base\_name](#input\_base\_name) | The {base} segment of the resource names. Lowercase letters, digits and single hyphens. The private endpoint names keep it in full. The storage account name is built from name\_short when set, else from base\_name: hyphens dropped, and as many characters as fit in 24 after site, the st type code, location and env (12 for ftdc4 in ncus with a one-letter env). | `string` | n/a | yes |
| <a name="input_blob_data_contributors"></a> [blob\_data\_contributors](#input\_blob\_data\_contributors) | Principals granted Storage Blob Data Contributor on the storage account, as { <key> = <principal (object) ID> }. The key is any fixed name, such as the consuming app; it keeps the role assignment's address stable when the principal ID is only known after apply. | `map(string)` | `{}` | no |
| <a name="input_blob_data_readers"></a> [blob\_data\_readers](#input\_blob\_data\_readers) | Principals granted Storage Blob Data Reader on the storage account, as { <key> = <principal (object) ID> }. | `map(string)` | `{}` | no |
| <a name="input_blob_delete_retention_days"></a> [blob\_delete\_retention\_days](#input\_blob\_delete\_retention\_days) | Days a deleted blob stays recoverable (blob soft delete), 1 to 365. | `number` | `7` | no |
| <a name="input_blob_versioning_enabled"></a> [blob\_versioning\_enabled](#input\_blob\_versioning\_enabled) | Whether the storage account keeps previous versions of overwritten blobs. | `bool` | `false` | no |
| <a name="input_container_delete_retention_days"></a> [container\_delete\_retention\_days](#input\_container\_delete\_retention\_days) | Days a deleted container stays recoverable (container soft delete), 1 to 365. | `number` | `7` | no |
| <a name="input_dns_resource_group_name"></a> [dns\_resource\_group\_name](#input\_dns\_resource\_group\_name) | Resource group, in the subscription the azurerm.ftdc4-production provider reaches, that holds the shared privatelink.blob.core.windows.net zone. | `string` | `"FTDC4-Network-P"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name per the FTI Resource Naming Standard §2.3. Accepts the short, medium or long spelling (case-insensitive) and normalizes to the short code used in every resource name: p (prod/production), d (dev/development), s (stage), t (test), u (uat), q (qa), x (sbx/sandbox). No other aliases are accepted. | `string` | n/a | yes |
| <a name="input_name_short"></a> [name\_short](#input\_name\_short) | Used in place of base\_name for the storage account name, the only name with a tight length limit. Lowercase letters, digits and single hyphens; the hyphens are dropped. If it is still too long, it is truncated. Defaults to base\_name. | `string` | `null` | no |
| <a name="input_private_dns_integration_enabled"></a> [private\_dns\_integration\_enabled](#input\_private\_dns\_integration\_enabled) | Whether to read the shared privatelink.blob.core.windows.net zone and attach a private\_dns\_zone\_group to the private endpoint. Set false to create the endpoint before the network team has the zone; setting it true later is an in-place update. | `bool` | `true` | no |
| <a name="input_private_endpoint_enabled"></a> [private\_endpoint\_enabled](#input\_private\_endpoint\_enabled) | Whether to create the blob private endpoint. | `bool` | `true` | no |
| <a name="input_private_link_subnet_name"></a> [private\_link\_subnet\_name](#input\_private\_link\_subnet\_name) | Name of the existing subnet the blob private endpoint goes in. Defaults to Application for prod and Dev-Application for every other environment. | `string` | `null` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the existing resource group the storage account and its private endpoint go in. The module reads it (it must already exist) and takes the location from it. | `string` | n/a | yes |
| <a name="input_shared_access_key_enabled"></a> [shared\_access\_key\_enabled](#input\_shared\_access\_key\_enabled) | Whether the storage account accepts its access keys and SAS tokens signed with them. Setting false leaves Entra ID (RBAC) as the only way in, and requires storage\_use\_azuread = true in the caller's azurerm provider block, because the provider reads the account's data plane while it plans. | `bool` | `true` | no |
| <a name="input_site"></a> [site](#input\_site) | Site a.k.a. Data Center (e.g., 'ftdc4') | `string` | `"ftdc4"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for every resource. The module adds Environment (the long form of the environment) unless this map sets it. | `map(string)` | `{}` | no |
| <a name="input_virtual_network_name"></a> [virtual\_network\_name](#input\_virtual\_network\_name) | Name of the existing Virtual Network that holds the private endpoint subnet. Defaults to FTDC4-Production1-P for prod and FTDC4-Development1-D for every other environment. | `string` | `null` | no |
| <a name="input_virtual_network_resource_group_name"></a> [virtual\_network\_resource\_group\_name](#input\_virtual\_network\_resource\_group\_name) | Resource group of that Virtual Network. Defaults to FTDC4-Network-P for prod and FTDC4-Network-D for every other environment. Match Azure's exact casing: subnet\_id is ForceNew on azurerm\_private\_endpoint, so a casing-only difference from state replaces the private endpoint. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_environment"></a> [environment](#output\_environment) | The short environment code used in resource names (e.g. 'd' for dev/development) |
| <a name="output_location"></a> [location](#output\_location) | The location code (standard §2.2) used in resource names, read from the resource group's region |
| <a name="output_primary_blob_endpoint"></a> [primary\_blob\_endpoint](#output\_primary\_blob\_endpoint) | The blob endpoint URL. Inside the network it resolves to the private endpoint's address through the shared privatelink zone. |
| <a name="output_private_endpoint_ip"></a> [private\_endpoint\_ip](#output\_private\_endpoint\_ip) | Private IP address of the blob private endpoint, or null when private\_endpoint\_enabled is false |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | The resource ID of the storage account |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | The name of the storage account |
