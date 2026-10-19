<!-- This file mirrors the terraform-docs output used by the shared modules.
     Regenerate with: terraform-docs markdown ./modules/terraform/sql_database_internal -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_mssql_database.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_database) | resource |
| [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_auto_pause_delay_in_minutes"></a> [auto\_pause\_delay\_in\_minutes](#input\_auto\_pause\_delay\_in\_minutes) | Serverless SKUs only: minutes without connections before the database pauses (and stops charging for compute), at least 15, or -1 to never pause. Ignored for other SKUs. | `number` | `60` | no |
| <a name="input_backup_storage_redundancy"></a> [backup\_storage\_redundancy](#input\_backup\_storage\_redundancy) | Redundancy of the database's backup storage: Geo, GeoZone, Local or Zone. Local keeps backups in one datacenter and costs least. | `string` | `"Geo"` | no |
| <a name="input_base_name"></a> [base\_name](#input\_base\_name) | The {base} segment of the database name: the workload name, the same base\_name as the server's. Lowercase letters, digits and single hyphens. | `string` | n/a | yes |
| <a name="input_collation"></a> [collation](#input\_collation) | The database's collation. Azure cannot change it after creation: a new value replaces the database. | `string` | `"SQL_Latin1_General_CP1_CI_AS"` | no |
| <a name="input_database_short_name"></a> [database\_short\_name](#input\_database\_short\_name) | The database's own name segment, written after the sqldb type code: {site}-{base}-sqldb-{database\_short\_name}-{location}-{env}. Lowercase letters, digits and single hyphens. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name per the FTI Resource Naming Standard §2.3. Accepts the short, medium or long spelling (case-insensitive) and normalizes to the short code used in every resource name: p (prod/production), d (dev/development), s (stage), t (test), u (uat), q (qa), x (sbx/sandbox). No other aliases are accepted. | `string` | n/a | yes |
| <a name="input_max_size_gb"></a> [max\_size\_gb](#input\_max\_size\_gb) | Maximum size of the database in GB. | `number` | `32` | no |
| <a name="input_min_capacity"></a> [min\_capacity](#input\_min\_capacity) | Serverless SKUs only: the fewest vCores the database keeps while it runs. Ignored for other SKUs. | `number` | `0.5` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the existing resource group that holds the server. The module reads its region for the location segment of the database name. | `string` | n/a | yes |
| <a name="input_server_id"></a> [server\_id](#input\_server\_id) | Resource ID of the SQL server the database goes on: sql\_server\_internal's server\_id output. | `string` | n/a | yes |
| <a name="input_short_term_retention_days"></a> [short\_term\_retention\_days](#input\_short\_term\_retention\_days) | Days of point-in-time restore, 1 to 35. | `number` | `7` | no |
| <a name="input_site"></a> [site](#input\_site) | Site a.k.a. Data Center (e.g., 'ftdc4') | `string` | `"ftdc4"` | no |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | The database's SKU, such as GP\_S\_Gen5\_1 (General Purpose serverless, up to 1 vCore) or GP\_Gen5\_2 (General Purpose provisioned, 2 vCores). A serverless SKU (GP\_S\_*) pauses after auto\_pause\_delay\_in\_minutes without connections. | `string` | `"GP_S_Gen5_1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for the database. The module adds Environment (the long form of the environment) unless this map sets it. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_database_id"></a> [database\_id](#output\_database\_id) | The resource ID of the database |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | The name of the database, for connection strings |
| <a name="output_environment"></a> [environment](#output\_environment) | The short environment code used in the database name (e.g. 'd' for dev/development) |
| <a name="output_location"></a> [location](#output\_location) | The location code (standard §2.2) used in the database name, read from the resource group's region |
