<!-- MODULE_METADATA
name: t-storage_account_internal
type: terraform
description: Private-only Azure Storage Account (StorageV2) with a blob private endpoint and Entra ID role assignments
current_version: 0.0.0
-->

# storage_account_internal Module

Creates a private-only Azure Storage Account with a blob private endpoint on the
application subnet, resolving through the shared
`privatelink.blob.core.windows.net` zone.

See [module-docs.md](module-docs.md) for the full input and output reference.

## What it creates

- **Storage account** (StorageV2, Standard, `public_network_access_enabled = false`,
  TLS 1.2, no anonymous blob access), with blob and container soft delete
- **Blob private endpoint** on the application subnet, registered in the shared
  `privatelink.blob.core.windows.net` zone
- **Role assignments** *(optional)*: `Storage Blob Data Contributor` for each
  entry in `blob_data_contributors`, `Storage Blob Data Reader` for each entry
  in `blob_data_readers`

> **Not created here:** containers, and private endpoints for file, queue,
> table or dfs. The development team that uses the account owns its containers.

## Naming

Names follow the FTI [Resource Naming Standard](https://enpti.atlassian.net/wiki/spaces/BI/pages/2320171009/Resource+Naming+Standard)
(§1): `{site}-{base}-{type}-{location}-{env}`, type `st`.

| Resource | Pattern | Example (`ncus`, `d`) |
|---|---|---|
| Storage account | `{site}{name_short or base}st{location}{env}`, hyphens removed | `ftdc4dagitdocsstncusd` |
| Private endpoint / connection / zone group | `{site}-{base}-st-pep-…` / `…-st-psc-…` / `…-st-dzg-…` | `ftdc4-dagit-docs-st-pep-ncus-d` |

`st` is the Cloud Adoption Framework abbreviation for a storage account. Register
it in the standard's §4 type list if it is not there yet.

**Length (§5).** A storage account name is 3 to 24 lowercase letters and digits,
and globally unique. The module keeps site, `st`, location and env in full and
shortens only base: first by using `name_short` in its place, as the servicebus
module does for its Key Vault, then by truncating. For `ftdc4` in `ncus` with a
one-letter env, 12 characters survive. Two names that agree in those 12
characters get the same storage account name, and Azure refuses the second one
at apply.

The infra-ops Storage Account request sets `base_name` to
`<workload>-<storage account name>` and `name_short` to the two names joined,
with the workload name cut so the whole storage account name fits
(`informaticasa` + `docs` → `informatdocs`). Before it generates anything, it
compares the result with every storage account the workload repositories
declare.

**Environment (§2.3)** and **location (§2.2)** work as in the servicebus module:
`environment` accepts the short, medium or long spelling, and the location code
comes from the resource group's region (`northcentralus` → `ncus`).

## Network defaults

| Input | Prod (`p`) | Non-prod (all others) |
|---|---|---|
| `virtual_network_name` | `FTDC4-Production1-P` | `FTDC4-Development1-D` |
| `virtual_network_resource_group_name` | `FTDC4-Network-P` | `FTDC4-Network-D` |
| `private_link_subnet_name` | `Application` | `Dev-Application` |

Set any of them to override. Match Azure's exact casing when you do:
`subnet_id` is ForceNew on `azurerm_private_endpoint`, so a casing-only change
replaces the private endpoint.

## Private DNS

The module reads `privatelink.blob.core.windows.net` from
`var.dns_resource_group_name` (default `FTDC4-Network-P`) through the
`azurerm.ftdc4-production` provider alias. It creates no zone and no Virtual
Network link; the network team owns those.

## Access

The account accepts Entra ID sign-ins through role assignments. Give the app
that uses it `Storage Blob Data Contributor` through `blob_data_contributors`,
keyed by a fixed name so the assignment's address does not depend on a
principal ID known only after apply:

```hcl
blob_data_contributors = {
  api = module.app_service_api[0].app_service_principal_id
}
```

`shared_access_key_enabled` defaults to `true`, as the storage account inside
`linux_app_service_internal` does. Setting it to `false` leaves Entra ID as the
only way in, and needs `storage_use_azuread = true` in the caller's `azurerm`
provider block: the provider reads the account's data plane while it plans.

## Usage

In a workload repository, the infra-ops Storage Account request writes a call
like this to `terraform/storage-accounts.tf`, and adds the module to the
repository's `platform.yaml`, which infra-platform-action reads to download the
module into `terraform/modules/`:

```hcl
module "storage_docs" {
  # live: the module creates the storage account only where the value is true.
  count = lookup({
    d = true
    p = false
    s = false
  }, var.environment, false) ? 1 : 0

  source = "./modules/storage_account_internal"
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.FTDC4-Production
  }

  site                = "ftdc4"
  environment         = var.environment
  base_name           = "dagit-docs"
  name_short          = "dagitdocs"
  resource_group_name = "ftdc4-dagit-${var.environment}"

  account_replication_type = {
    d = "LRS"
    s = "LRS"
    p = "GRS"
  }[var.environment]

  tags = {
    CreatedBy        = "INF Terraform"
    Asset            = "dagit-docs"
    OperationalOwner = "DAG"
    MaintainedBy     = "BT Systems"
  }
}
```

## Notes

- Setting an environment from `true` to `false` in the caller's `live` map, or
  removing the module call, deletes the storage account and every blob in it.
  The plan on the pull request lists the destroy before anyone merges it.
- The `privatelink.blob.core.windows.net` zone must already exist in
  `dns_resource_group_name` and be linked to the application Virtual Network.

## Tests

`tests/storage_account.tftest.hcl` plans the module against mock providers, so
it needs no Azure credentials. From this directory: `tofu init`, then
`tofu test` (or `terraform init`, then `terraform test`).
