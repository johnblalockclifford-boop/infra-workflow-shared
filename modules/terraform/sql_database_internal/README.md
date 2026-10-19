<!-- MODULE_METADATA
name: t-sql_database_internal
type: terraform
description: One Azure SQL database on a server created by sql_server_internal
current_version: 0.0.0
-->

# sql_database_internal Module

Creates one Azure SQL database on a server that
[`sql_server_internal`](../sql_server_internal) created. The database is reached
through that server's private endpoint and uses its Entra ID administrators, so
this module creates no network resources.

See [module-docs.md](module-docs.md) for the full input and output reference.

## What it creates

- **SQL database** with the SKU in `sku_name` (default `GP_S_Gen5_1`, General
  Purpose serverless), point-in-time restore for `short_term_retention_days`
  (default 7), and backups stored with `backup_storage_redundancy` (default
  `Geo`). A serverless database pauses after `auto_pause_delay_in_minutes`
  (default 60) without connections and stops charging for compute while paused.

> **Not created here:** database users and roles (the server's administrators
> group creates them; see `sql_server_internal`), long-term retention, and
> geo-replicas.

## Naming

`{site}-{base}-sqldb-{database_short_name}-{location}-{env}`, the pattern the
servicebus module uses for its SAS rules: the parent's `{site}-{base}`, the
type, then the item's own name.

| Resource | Example (`ncus`, `d`) |
|---|---|
| SQL database | `ftdc4-dagit-sqldb-orders-ncus-d` |

`sqldb` is the Cloud Adoption Framework abbreviation for an Azure SQL database.
Register it in the standard's §4 type list if it is not there yet.

The location code comes from the region of `resource_group_name`, the resource
group that holds the server.

## Usage

In a workload repository, the infra-ops SQL Database request writes one call
like this per database to `terraform/sql.tf`, and adds the module to
`platform.yaml`:

```hcl
module "sql_database_orders" {
  # live: the module creates the database only where the value is true. The
  # sql_server block must be live in the same environments.
  count = lookup({
    d = true
    p = false
    s = false
  }, var.environment, false) ? 1 : 0

  source = "./modules/sql_database_internal"

  site                = "ftdc4"
  environment         = var.environment
  base_name           = "dagit"
  database_short_name = "orders"
  resource_group_name = "ftdc4-dagit-${var.environment}"
  server_id           = one(module.sql_server[*].server_id)

  sku_name = {
    d = "GP_S_Gen5_1"
    s = "GP_S_Gen5_1"
    p = "GP_S_Gen5_2"
  }[var.environment]
  backup_storage_redundancy = var.environment == "p" ? "Geo" : "Local"

  tags = {
    CreatedBy        = "INF Terraform"
    Asset            = "dagit-orders"
    OperationalOwner = "DAG"
    MaintainedBy     = "BT Systems"
  }
}
```

`one(module.sql_server[*].server_id)` is null in an environment where the
server's module call creates nothing, and a null `server_id` fails the plan with
a message saying to set that environment to `true` in the server's `live` map.

## Notes

- Removing the module call, or setting its environment from `true` to `false`
  in the `live` map, deletes the database. Azure keeps a deleted database
  restorable for its short-term retention period, as long as the server exists.
- `collation` cannot change after creation: a new value replaces the database.

## Tests

`tests/sql_database.tftest.hcl` plans the module against a mock provider. From
this directory: `tofu init`, then `tofu test` (or the `terraform` equivalents).
