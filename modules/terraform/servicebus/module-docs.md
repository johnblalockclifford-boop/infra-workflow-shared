<!-- This file mirrors the terraform-docs output used by the shared modules.
     Regenerate with: terraform-docs markdown ./modules/terraform/servicebus -->

## Requirements

| Name | Version |
|------|---------|
| azurerm | ~> 4.0 |
| time | ~> 0.9 |

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.0 |
| azurerm.ftdc4-production | ~> 4.0 |
| time | ~> 0.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_servicebus_namespace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_namespace) | resource |
| [azurerm_servicebus_namespace_authorization_rule.sas](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_namespace_authorization_rule) | resource |
| [azurerm_servicebus_namespace_disaster_recovery_config.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_namespace_disaster_recovery_config) | resource |
| [azurerm_private_endpoint.servicebus](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_private_endpoint.keyvault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_user_assigned_identity.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_role_assignment.uami_sender](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.uami_receiver](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_role_assignment.runner_secrets_officer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.uami_secrets_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_key_vault_secret.sas](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [time_sleep.keyvault_pe_dns_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |
| [azurerm_subnet.private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_private_dns_zone.servicebus](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |
| [azurerm_private_dns_zone.keyvault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_site"></a> [site](#input\_site) | Site a.k.a. Data Center (e.g., 'ftdc4') | `string` | `"ftdc4"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment per standard §2.3. Accepts short/medium/long spelling (p/prod/production, d/dev/development, s/stage, t/test, u/uat, q/qa, x/sbx/sandbox); normalized to the short code. No other aliases. | `string` | n/a | yes |
| <a name="input_base_name"></a> [base\_name](#input\_base\_name) | Workload name ({base} segment). Lowercase letters, digits, single hyphens. The only segment shortened to meet length limits. | `string` | n/a | yes |
| <a name="input_name_short"></a> [name\_short](#input\_name\_short) | Short form of base\_name used for length-constrained resources (Key Vault); truncated if still too long. Defaults to base_name. | `string` | `null` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the existing resource group the resources are created in. Referenced, not created. | `string` | n/a | yes |
| <a name="input_virtual_network_name"></a> [virtual\_network\_name](#input\_virtual\_network\_name) | Name of the existing application VNet hosting the PE subnet. Defaults per-env (prod → FTDC4-Production1-P, non-prod → FTDC4-Development1-D). | `string` | `null` | no |
| <a name="input_virtual_network_resource_group_name"></a> [virtual\_network\_resource\_group\_name](#input\_virtual\_network\_resource\_group\_name) | Resource group containing the VNet. Defaults per-env (prod → FTDC4-Network-P, non-prod → FTDC4-Network-D). Match Azure's exact casing when overriding — subnet\_id is ForceNew, so a casing-only diff replaces both private endpoints. | `string` | `null` | no |
| <a name="input_private_link_subnet_name"></a> [private\_link\_subnet\_name](#input\_private\_link\_subnet\_name) | Subnet for the Service Bus / Key Vault private endpoints. Defaults per-env (prod → Application, non-prod → Dev-Application). | `string` | `null` | no |
| <a name="input_private_endpoint_enabled"></a> [private\_endpoint\_enabled](#input\_private\_endpoint\_enabled) | Whether to create the private endpoints and DNS integration | `bool` | `true` | no |
| <a name="input_dns_resource_group_name"></a> [dns\_resource\_group\_name](#input\_dns\_resource\_group\_name) | Resource group (in the production hub subscription) that holds the shared privatelink DNS zones. | `string` | `"FTDC4-Network-P"` | no |
| <a name="input_private_dns_integration_enabled"></a> [private\_dns\_integration\_enabled](#input\_private\_dns\_integration\_enabled) | Whether to look up the shared privatelink DNS zones and attach a private\_dns\_zone\_group to each private endpoint. Set false to deploy the endpoints before the network team has provisioned the DNS zones. | `bool` | `true` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | SKU for the Service Bus namespace (Premium is required for private endpoints) | `string` | `"Premium"` | no |
| <a name="input_capacity"></a> [capacity](#input\_capacity) | Messaging units for the Premium namespace (1, 2, 4, 8 or 16) | `number` | `1` | no |
| <a name="input_premium_messaging_partitions"></a> [premium\_messaging\_partitions](#input\_premium\_messaging\_partitions) | Number of messaging partitions (Premium only) | `number` | `1` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Whether public network access is allowed to the namespace. Must be false for the private-only architecture. | `bool` | `false` | no |
| <a name="input_geo_disaster_recovery_enabled"></a> [geo\_disaster\_recovery\_enabled](#input\_geo\_disaster\_recovery\_enabled) | Enable Geo-Disaster Recovery (active/passive). Prod only — requires a partner Premium namespace in the paired region. | `bool` | `false` | no |
| <a name="input_geo_dr_alias_name"></a> [geo\_dr\_alias\_name](#input\_geo\_dr\_alias\_name) | Alias name for the Geo-DR pairing. Defaults to {site}-{base}-geodr-{location}-{env} when omitted. | `string` | `null` | no |
| <a name="input_geo_dr_partner_namespace_id"></a> [geo\_dr\_partner\_namespace\_id](#input\_geo\_dr\_partner\_namespace\_id) | Resource ID of the secondary (partner) namespace. Required when geo\_disaster\_recovery\_enabled is true. | `string` | `null` | no |
| <a name="input_uami_enabled"></a> [uami\_enabled](#input\_uami\_enabled) | Whether to create the User-Assigned Managed Identity and grant it Service Bus data-plane roles | `bool` | `true` | no |
| <a name="input_onprem_sas_apps"></a> [onprem\_sas\_apps](#input\_onprem\_sas\_apps) | On-prem apps that authenticate with a SAS token. Each entry creates a namespace authorization rule and stores its connection string in Key Vault as {site}-{base\_name}-sas-{env}-{key}. | `map(object({ listen = optional(bool, true), send = optional(bool, true), manage = optional(bool, false) }))` | `{}` | no |
| <a name="input_key_vault_enabled"></a> [key\_vault\_enabled](#input\_key\_vault\_enabled) | Whether to create a Key Vault for the environment | `bool` | `true` | no |
| <a name="input_key_vault_sku_name"></a> [key\_vault\_sku\_name](#input\_key\_vault\_sku\_name) | SKU for the Key Vault | `string` | `"standard"` | no |
| <a name="input_key_vault_soft_delete_days"></a> [key\_vault\_soft\_delete\_days](#input\_key\_vault\_soft\_delete\_days) | Soft delete retention in days for the Key Vault | `number` | `7` | no |
| <a name="input_key_vault_purge_protection_enabled"></a> [key\_vault\_purge\_protection\_enabled](#input\_key\_vault\_purge\_protection\_enabled) | Whether to enable purge protection on the Key Vault (recommended for prod) | `bool` | `false` | no |
| <a name="input_key_vault_network_acls_ip_rules"></a> [key\_vault\_network\_acls\_ip\_rules](#input\_key\_vault\_network\_acls\_ip\_rules) | CIDR ranges allowed through the Key Vault firewall in addition to the private endpoint. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_environment"></a> [environment](#output\_environment) | The normalized short environment code used in resource names (e.g. 'd') |
| <a name="output_location"></a> [location](#output\_location) | Location code (standard §2.2) used in names, derived from the resource group region |
| <a name="output_namespace_id"></a> [namespace\_id](#output\_namespace\_id) | The resource ID of the Service Bus namespace |
| <a name="output_namespace_name"></a> [namespace\_name](#output\_namespace\_name) | The name of the Service Bus namespace |
| <a name="output_private_endpoint_ip"></a> [private\_endpoint\_ip](#output\_private\_endpoint\_ip) | Private IP address of the Service Bus private endpoint |
| <a name="output_uami_client_id"></a> [uami\_client\_id](#output\_uami\_client\_id) | Client ID of the User-Assigned Managed Identity (for DefaultAzureCredential) |
| <a name="output_uami_principal_id"></a> [uami\_principal\_id](#output\_uami\_principal\_id) | Principal (object) ID of the User-Assigned Managed Identity |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | The resource ID of the Key Vault, if created |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | The name of the Key Vault, if created |
| <a name="output_geo_dr_alias_id"></a> [geo\_dr\_alias\_id](#output\_geo\_dr\_alias\_id) | Resource ID of the Geo-DR alias, if Geo-Disaster Recovery is enabled |
