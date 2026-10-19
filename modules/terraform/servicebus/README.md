<!-- MODULE_METADATA
name: t-servicebus
type: terraform
description: Private-only Azure Service Bus (Premium) with UAMI RBAC, on-prem SAS auth, and a private Key Vault
current_version: 1.0.0
last_updated: 2026-10-07T17:43:00.626649
-->

# servicebus Module

Creates a private-only Azure Service Bus namespace (Premium) with everything needed
for on-prem and Azure App Service consumers, and a private Key Vault to hold
on-prem SAS connection strings.

> **Promoted from `ftdc4-infra-servicebus`.** This module started as a local
> module in that repo (`terraform/modules/servicebus`), deliberately authored in
> this shared-module style so it could be promoted here later with minimal
> changes. See [CHANGELOG.md](CHANGELOG.md) for the full history and the
> features carried over from that repo.

See [module-docs.md](module-docs.md) for the full input/output reference.

## What it creates

- **Service Bus namespace** (Premium, `public_network_access_enabled = false`)
- **Service Bus private endpoint** on the app subnet, resolving via the shared
  `privatelink.servicebus.windows.net` zone
- **User-Assigned Managed Identity** granted `Azure Service Bus Data Sender` and
  `Data Receiver` on the namespace (see [Managed identity](#managed-identity))
- **Namespace SAS authorization rules** — one per on-prem app
- **Key Vault** (private-endpoint only, RBAC-authorized) resolving via the shared
  `privatelink.vaultcore.azure.net` zone
- **Key Vault secrets** holding each on-prem app's SAS connection string
- **Geo-Disaster Recovery alias** *(optional, prod only)* — active/passive pairing
  with a partner namespace, created only when `geo_disaster_recovery_enabled = true`

> **Not created here:** queues, topics and subscriptions (and their TTL / lock /
> delivery settings) are owned by the development teams that consume the
> namespace. This module provisions the namespace and its access plumbing only.

## Naming

All names follow the FTI [Resource Naming Standard](https://enpti.atlassian.net/wiki/spaces/BI/pages/2320171009/Resource+Naming+Standard)
(§1): `{site}-{base}-{type}-{location}-{env}`. Child resources take the parent's
`{site}-{base}-{type}` followed by their own type.

| Resource | Pattern | Example (`ncus`, `p`) |
|---|---|---|
| Namespace | `{site}-{base}-sbns-{location}-{env}` | `ftdc4-myapp-sbns-ncus-p` |
| Service Bus PE / connection / zone group | `…-sbns-pep-…` / `…-sbns-psc-…` / `…-sbns-dzg-…` | `ftdc4-myapp-sbns-pep-ncus-p` |
| UAMI | `{site}-{base}-id-{location}-{env}` | `ftdc4-myapp-id-ncus-p` |
| Key Vault | `{site}-{base}-kv-{location}-{env}` | `ftdc4-myapp-kv-ncus-p` |
| Key Vault PE / connection / zone group | `…-kv-pep-…` / `…-kv-psc-…` / `…-kv-dzg-…` | `ftdc4-myapp-kv-pep-ncus-p` |
| SAS rule / secret | `{site}-{base}-sas-{app}-{location}-{env}` | `ftdc4-myapp-sas-erp-ncus-p` |
| Geo-DR alias | `{site}-{base}-geodr-{location}-{env}` | `ftdc4-myapp-geodr-ncus-p` |

> `sas` and `geodr` are not yet in the standard's §4 type list; they should be
> registered there.

**Environment (§2.3).** `environment` accepts the short, medium or long spelling
(case-insensitive) and resolves to the short code used in names: `p`
(prod/production), `d` (dev/development), `s` (stage), `t` (test), `u` (uat),
`q` (qa), `x` (sbx/sandbox). There are no other aliases — `np`, `nonprod` and
`stg` are rejected, and `uat`/`qa` are their own environments rather than
synonyms for `test`/`stage`. The module injects an `Environment` tag using the
standard's long form (`Production`, `Development`, …); pass your own
`Environment` key in `tags` to override it.

**Location (§2.2).** The location code is derived from the resource group's
region (`northcentralus` → `ncus`, `centralus` → `cus`, `eastus2` → `eus2`), so
names can't drift from where the resources really are. A region with no code
fails the plan; add it to the standard and to `local.location_code_map` first.

**Length limits (§5).** Only `base` is ever shortened — site, type, location and
env are always preserved in full. For the Key Vault (24-character limit, so about
8 characters of base for `ftdc4` + `ncus`), the module uses `name_short` in place
of `base_name` when set, then truncates to fit, trimming any trailing hyphen.
Callers don't need to pre-shorten anything. Truncation only affects the Key
Vault and its private endpoint; the namespace keeps the full base unless it would
exceed its own 50-character limit.

> **Breaking change.** These names differ from the pre-standard module
> (`{site}-{base}-{env}`, `…-pe-…`, `…-uami-…`). Renaming a namespace, Key Vault,
> identity or private endpoint forces replacement, so adopting this version on an
> existing deployment is destructive. It is intended for new deployments; release
> it as a **major** version (`.bumpver servicebus major`).

## Managed identity

The module creates a **User-Assigned Managed Identity (UAMI)** and grants it the
`Azure Service Bus Data Sender` and `Data Receiver` roles on the namespace (and
`Key Vault Secrets User` on the vault when one is created).

- **Who consumes it:** the Azure App Service(s) that talk to this namespace —
  provisioned by the shared [`linux_app_service_internal`](../linux_app_service_internal)
  module. That deployment assigns this identity to the App Service and sets
  `AZURE_CLIENT_ID` from this module's `uami_client_id` output, so the app
  authenticates with `DefaultAzureCredential` — no secrets, no connection strings.
- **Why user-assigned instead of system-assigned:** the identity and its RBAC role
  assignments exist independently of, and before, the App Service. That avoids a
  first-deploy chicken-and-egg, lets the app be recreated without re-granting Service
  Bus / Key Vault roles, and lets one identity be shared across multiple apps, slots
  or instances on the same namespace.
- On-prem / legacy apps that can't use managed identity use the SAS rules instead
  (see `onprem_sas_apps`). Set `uami_enabled = false` if a deployment has only SAS
  consumers.

## Network defaults

`virtual_network_name`, `virtual_network_resource_group_name` and
`private_link_subnet_name` all default by environment so most deployments don't set
them. **Prod** stays isolated on the production network; **every non-prod
environment** (`d`, `s`, `t`, `u`, `q`, `x`) shares the
development network:

| Input | Prod (`p`) | Non-prod (all others) |
|---|---|---|
| `virtual_network_name` | `FTDC4-Production1-P` | `FTDC4-Development1-D` |
| `virtual_network_resource_group_name` | `FTDC4-Network-P` | `FTDC4-Network-D` |
| `private_link_subnet_name` | `Application` | `Dev-Application` |

Each is independently overridable — set the matching input to place a deployment on
a different VNet or subnet (e.g. when a new environment gets its own network).

> **Match Azure's exact casing when overriding.** `subnet_id` is ForceNew on
> `azurerm_private_endpoint` and Terraform diffs it as a plain string, so passing
> `ftdc4-network-d` where state holds `FTDC4-Network-D` replaces both private
> endpoints — new private IPs and a connectivity gap — even though Azure itself
> treats the two spellings as the same resource.

## Private DNS

The `privatelink.servicebus.windows.net` and `privatelink.vaultcore.azure.net`
zones are **referenced** from the production network hub
(`var.dns_resource_group_name`, default `FTDC4-Network-P`) via the
`azurerm.ftdc4-production` provider alias. The module does not create zones or
VNet links — the network team owns those.

## Usage

```hcl
module "servicebus" {
  source = "git::https://github.com/Faith-Technologies/infra-workflow-shared.git//modules/terraform/servicebus"
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.FTDC4-Production
  }

  site        = "ftdc4"
  environment = "dev" # accepts dev / development / d
  base_name   = "myapp"
  name_short  = "myapp" # optional; used in place of base_name for the Key Vault

  resource_group_name = "ftdc4-servicebus-d"

  # Existing app VNet + subnet (referenced, not created). Optional — omit to use
  # the per-env defaults (dev network for non-prod, prod network for prod). Set
  # any of these to override:
  # virtual_network_name                = "FTDC4-Development1-D"
  # virtual_network_resource_group_name = "FTDC4-Network-D"
  # private_link_subnet_name            = "Dev-Application"

  # Sizing
  sku      = "Premium"
  capacity = 1

  # On-prem legacy apps that use a SAS token (optional)
  onprem_sas_apps = {
    erp = { listen = true, send = true, manage = false }
  }

  # Environment is auto-tagged from the normalized env; add your own keys here.
  tags = {
    CreatedBy        = "INF Terraform"
    Asset            = "sbns"
    OperationalOwner = "DAG"
    MaintainedBy     = "BT Systems"
  }
}

# Wire the UAMI into an App Service deployed by linux_app_service_internal
output "uami_client_id" {
  value = module.servicebus.uami_client_id
}
```

Pin to a specific released version with a `ref`, matching the module's git tag
(see [Module Automation](../../../README.md#module-automation)):

```hcl
source = "git::https://github.com/Faith-Technologies/infra-workflow-shared.git//modules/terraform/servicebus?ref=servicebus.v0.1.0"
```

## Notes

- **Premium is required** for private endpoints. `capacity` and
  `premium_messaging_partitions` are ignored for non-Premium SKUs.
- **Writing SAS secrets to a private vault:** because the Key Vault is
  private-only with a `Deny` default ACL, the identity running `terraform apply`
  must reach the vault data plane — either from a runner on the VNet / over the
  VPN, or by allowlisting its egress IP via `key_vault_network_acls_ip_rules`.
  This only matters when `onprem_sas_apps` is non-empty.
- The `privatelink.servicebus.windows.net` and `privatelink.vaultcore.azure.net`
  DNS zones must already exist in `dns_resource_group_name` and be linked to the
  app VNet by the network team.
- **Key Vault soft-delete on rename/destroy:** destroying the vault (including any
  rename that forces replacement) soft-deletes it. The azurerm provider will also
  try to *purge* it unless the caller sets `purge_soft_delete_on_destroy = false`
  in the `azurerm` provider `features { key_vault { … } }` block. Purging requires
  `Microsoft.KeyVault/locations/deletedVaults/purge/action` at the subscription
  scope; if the Terraform runner lacks it the destroy fails with a 403. Either
  disable purge-on-destroy (the soft-deleted vault auto-purges after
  `key_vault_soft_delete_days`) or grant the runner purge rights.
