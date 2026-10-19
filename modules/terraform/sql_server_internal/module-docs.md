<!-- This file mirrors the terraform-docs output used by the shared modules.
     Regenerate with: terraform-docs markdown ./modules/terraform/sql_server_internal -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | ~> 3.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.0 |
| <a name="provider_azurerm.ftdc4-production"></a> [azurerm.ftdc4-production](#provider\_azurerm.ftdc4-production) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_mssql_server.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_server) | resource |
| [azurerm_private_endpoint.sql](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azuread_group.administrators](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/group) | data source |
| [azurerm_private_dns_zone.sql](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_subnet.private_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_administrator_group_name"></a> [administrator\_group\_name](#input\_administrator\_group\_name) | Display name of the Entra ID security group that administers the server. The module reads the group through the azuread provider, so the identity running the plan needs to read groups (Group.Read.All or Directory.Read.All in Microsoft Graph). The server accepts Entra ID sign-ins only: it has no SQL administrator login. | `string` | n/a | yes |
| <a name="input_base_name"></a> [base\_name](#input\_base\_name) | The {base} segment of the resource names: the workload name. Lowercase letters, digits and single hyphens. The server name keeps as much of base as fits in 63 characters. | `string` | n/a | yes |
| <a name="input_dns_resource_group_name"></a> [dns\_resource\_group\_name](#input\_dns\_resource\_group\_name) | Resource group, in the subscription the azurerm.ftdc4-production provider reaches, that holds the shared privatelink.database.windows.net zone. | `string` | `"FTDC4-Network-P"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name per the FTI Resource Naming Standard §2.3. Accepts the short, medium or long spelling (case-insensitive) and normalizes to the short code used in every resource name: p (prod/production), d (dev/development), s (stage), t (test), u (uat), q (qa), x (sbx/sandbox). No other aliases are accepted. | `string` | n/a | yes |
| <a name="input_private_dns_integration_enabled"></a> [private\_dns\_integration\_enabled](#input\_private\_dns\_integration\_enabled) | Whether to read the shared privatelink.database.windows.net zone and attach a private\_dns\_zone\_group to the private endpoint. Set false to create the endpoint before the network team has the zone; setting it true later is an in-place update. | `bool` | `true` | no |
| <a name="input_private_endpoint_enabled"></a> [private\_endpoint\_enabled](#input\_private\_endpoint\_enabled) | Whether to create the SQL server's private endpoint. | `bool` | `true` | no |
| <a name="input_private_link_subnet_name"></a> [private\_link\_subnet\_name](#input\_private\_link\_subnet\_name) | Name of the existing subnet the SQL server's private endpoint goes in. Defaults to Application for prod and Dev-Application for every other environment. | `string` | `null` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the existing resource group the SQL server and its private endpoint go in. The module reads it (it must already exist) and takes the location from it. | `string` | n/a | yes |
| <a name="input_site"></a> [site](#input\_site) | Site a.k.a. Data Center (e.g., 'ftdc4') | `string` | `"ftdc4"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for every resource. The module adds Environment (the long form of the environment) unless this map sets it. | `map(string)` | `{}` | no |
| <a name="input_virtual_network_name"></a> [virtual\_network\_name](#input\_virtual\_network\_name) | Name of the existing Virtual Network that holds the private endpoint subnet. Defaults to FTDC4-Production1-P for prod and FTDC4-Development1-D for every other environment. | `string` | `null` | no |
| <a name="input_virtual_network_resource_group_name"></a> [virtual\_network\_resource\_group\_name](#input\_virtual\_network\_resource\_group\_name) | Resource group of that Virtual Network. Defaults to FTDC4-Network-P for prod and FTDC4-Network-D for every other environment. Match Azure's exact casing: subnet\_id is ForceNew on azurerm\_private\_endpoint, so a casing-only difference from state replaces the private endpoint. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_administrator_group_object_id"></a> [administrator\_group\_object\_id](#output\_administrator\_group\_object\_id) | Object ID of the Entra ID group that administers the server |
| <a name="output_environment"></a> [environment](#output\_environment) | The short environment code used in resource names (e.g. 'd' for dev/development) |
| <a name="output_fully_qualified_domain_name"></a> [fully\_qualified\_domain\_name](#output\_fully\_qualified\_domain\_name) | The server's host name (<name>.database.windows.net). Inside the network it resolves to the private endpoint's address through the shared privatelink zone. |
| <a name="output_location"></a> [location](#output\_location) | The location code (standard §2.2) used in resource names, read from the resource group's region |
| <a name="output_private_endpoint_ip"></a> [private\_endpoint\_ip](#output\_private\_endpoint\_ip) | Private IP address of the SQL server's private endpoint, or null when private\_endpoint\_enabled is false |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | The resource ID of the SQL server. Pass it to sql\_database\_internal's server\_id. |
| <a name="output_server_name"></a> [server\_name](#output\_server\_name) | The name of the SQL server |
