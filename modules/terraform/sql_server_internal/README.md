<!-- MODULE_METADATA
name: t-sql_server_internal
type: terraform
description: Private-only Azure SQL logical server with Entra ID-only authentication and a private endpoint
current_version: 0.0.0
-->

# sql_server_internal Module

Creates a private-only Azure SQL logical server that accepts Entra ID sign-ins
only, administered by an Entra ID security group, with a private endpoint on the
application subnet resolving through the shared
`privatelink.database.windows.net` zone.

Databases are a separate module,
[`sql_database_internal`](../sql_database_internal): one server per workload,
one `sql_database_internal` call per database on it.

See [module-docs.md](module-docs.md) for the full input and output reference.

## What it creates

- **SQL server** (version 12.0, `public_network_access_enabled = false`,
  TLS 1.2), with the group named in `administrator_group_name` as its Entra ID
  administrator and `azuread_authentication_only = true`: no SQL logins, and no
  SQL administrator password to keep anywhere
- **Private endpoint** (`sqlServer`) on the application subnet, registered in the
  shared `privatelink.database.windows.net` zone

> **Not created here:** databases (`sql_database_internal`), database users,
> auditing, and Microsoft Defender for SQL.

## Naming

Names follow the FTI [Resource Naming Standard](https://enpti.atlassian.net/wiki/spaces/BI/pages/2320171009/Resource+Naming+Standard)
(§1): `{site}-{base}-{type}-{location}-{env}`, type `sql`.

| Resource | Pattern | Example (`ncus`, `d`) |
|---|---|---|
| SQL server | `{site}-{base}-sql-{location}-{env}` | `ftdc4-dagit-sql-ncus-d` |
| Private endpoint / connection / zone group | `…-sql-pep-…` / `…-sql-psc-…` / `…-sql-dzg-…` | `ftdc4-dagit-sql-pep-ncus-d` |

`sql` is the Cloud Adoption Framework abbreviation for an Azure SQL server.
Register it in the standard's §4 type list if it is not there yet.

A server name is 1 to 63 characters and globally unique
(`<name>.database.windows.net`). Only base is shortened to fit.

**Environment (§2.3)** and **location (§2.2)** work as in the servicebus module.

## Administrators

`administrator_group_name` is the display name of an Entra ID **security**
group. The module reads the group through the `azuread` provider, so the
identity that runs the plan needs to read groups in Microsoft Graph
(`Group.Read.All` or `Directory.Read.All`). A name that matches no security
group fails the plan with the provider's lookup error, and so does a name that
matches more than one.

Members of the group sign in with Entra ID and create the database users the
applications need (`CREATE USER [<name>] FROM EXTERNAL PROVIDER`, then
`ALTER ROLE ... ADD MEMBER`). For a managed identity or service principal,
Azure SQL has to resolve the identity in Entra ID; Microsoft's documentation on
Microsoft Entra service principals with Azure SQL lists the ways to allow that.
This module gives the server no managed identity.

## Network defaults

| Input | Prod (`p`) | Non-prod (all others) |
|---|---|---|
| `virtual_network_name` | `FTDC4-Production1-P` | `FTDC4-Development1-D` |
| `virtual_network_resource_group_name` | `FTDC4-Network-P` | `FTDC4-Network-D` |
| `private_link_subnet_name` | `Application` | `Dev-Application` |

Set any of them to override, in Azure's exact casing (`subnet_id` is ForceNew on
`azurerm_private_endpoint`).

## Private DNS

The module reads `privatelink.database.windows.net` from
`var.dns_resource_group_name` (default `FTDC4-Network-P`) through the
`azurerm.ftdc4-production` provider alias. It creates no zone and no Virtual
Network link; the network team owns those.

## Usage

In a workload repository, the infra-ops SQL Database request writes this call
to `terraform/sql.tf` with the workload's first database, and adds the module
to `platform.yaml`:

```hcl
module "sql_server" {
  # live: the module creates the server only where the value is true. Every
  # sql_database_* call in this file needs the server live in its environments.
  count = lookup({
    d = true
    p = true
    s = false
  }, var.environment, false) ? 1 : 0

  source = "./modules/sql_server_internal"
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.FTDC4-Production
  }

  site                     = "ftdc4"
  environment              = var.environment
  base_name                = "dagit"
  resource_group_name      = "ftdc4-dagit-${var.environment}"
  administrator_group_name = "SG-Dagit-SQL-Admins"

  tags = {
    CreatedBy        = "INF Terraform"
    Asset            = "dagit-sql"
    OperationalOwner = "DAG"
    MaintainedBy     = "BT Systems"
  }
}
```

## Notes

- A logical server costs nothing by itself; its private endpoint is billed by
  the hour.
- Removing the module call, or setting an environment to `false` in its `live`
  map, deletes the server. Set every database on it to `false` in that
  environment first: a database whose server is gone fails the plan with
  `server_id is null`.
- The `privatelink.database.windows.net` zone must already exist in
  `dns_resource_group_name` and be linked to the application Virtual Network.

## Tests

`tests/sql_server.tftest.hcl` plans the module against mock providers. From
this directory: `tofu init`, then `tofu test` (or the `terraform` equivalents).
