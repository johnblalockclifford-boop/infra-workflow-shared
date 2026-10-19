# Changelog for servicebus

## Unreleased — Align naming with the FTI Resource Naming Standard (**breaking**)

## Version 1.0.0 (2026-10-07T17:43:00.626649)

- No specific changes logged
Resource names now follow the
[Resource Naming Standard](https://enpti.atlassian.net/wiki/spaces/BI/pages/2320171009/Resource+Naming+Standard)
(`{site}-{base}-{type}-{location}-{env}`), addressing review feedback on the
environment map and on length-constrained names. **Renaming forces replacement of
the namespace, Key Vault, identity and private endpoints — release as a major
version (`.bumpver servicebus major`) and use for new deployments only.**

### Changed

- **Names:** `{site}-{base}-{env}` → `{site}-{base}-sbns-{location}-{env}`;
  `-pe-` → `-pep-` with `-psc` / `-dzg` children; `-uami-` → `-id-`;
  `-kv-` / `-kv-pe-` gain the location segment; SAS rules/secrets and the
  Geo-DR alias are now `…-{location}-{env}` (env last).
- **Environment map** now matches standard §2.3 exactly: `p d s t u q x` plus
  their medium/long spellings. Removed the non-standard aliases `np`, `nonprod`,
  `stg`, and `uat`/`qa` no longer collapse onto `test`/`stage`. Added `u`, `q`, `x`.
  Non-prod environments still share the development network.
- **`base_name` is now required** (the `sbns` default would produce
  `ftdc4-sbns-sbns-…`) and validated (lowercase, digits, single hyphens).

### Added

- Location code derived from the resource group region (`ncus`, `cus`, `eus2`),
  with a plan-time error for unregistered regions; exposed as the `location` output.
- `name_short` input. The Key Vault name uses it (then truncates `base`, never the
  other segments) to fit Azure's 24-character limit, so callers no longer
  pre-shorten names.

---

## Unreleased — Promoted to infra-workflow-shared (2026-09-28)

## Version 0.0.1 (2026-10-01T12:22:51.856528)

- No specific changes logged
Promoted from a local module in `ftdc4-infra-servicebus`
(`terraform/modules/servicebus`) into this shared-modules repo, so other teams
can reference it directly. No functional changes — the module was already
authored in the shared-module style (flat layout, `.this` resource naming,
`provider.tf` with `configuration_aliases` only, `MODULE_METADATA` header)
specifically so it could be promoted with minimal changes.

It carries forward everything built up across 1.0.0 – 1.1.1 in the source repo
(see **Prior history** below for the detailed, dated notes):

- Private-only Service Bus namespace (Premium), no public network access
- Private endpoints (Service Bus + Key Vault) resolved via the shared
  `privatelink.servicebus.windows.net` / `privatelink.vaultcore.azure.net`
  zones, with a toggle to deploy before DNS zones exist
- User-Assigned Managed Identity with `Data Sender` / `Data Receiver` RBAC,
  for App Service `DefaultAzureCredential` consumers
- Namespace SAS authorization rules + Key Vault secrets for on-prem/legacy apps
- Private, RBAC-authorized Key Vault with runner/UAMI role grants and a
  DNS-propagation guard before writing secrets
- Optional prod-only Geo-Disaster Recovery alias
- Per-environment network defaults (prod vs. shared non-prod) and environment
  name normalization/aliasing, with Azure-casing-correct defaults and
  Key-Vault-name-length guarding

This repo's module automation derives the actual version from this module's own
git tags (`servicebus.v<major>.<minor>.<patch>`), not from this file, and starts
a newly-added module at `0.0.0` — so the first release here is tagged and
versioned by that automation (default: `servicebus.v0.0.1`) rather than by the
version numbers below, which are carried over from the source repo's history.
See the top-level [README](../../../README.md#module-automation) for how to
override the suggested bump via PR comment if a later change warrants it.

---

**Prior history (in `ftdc4-infra-servicebus`, pre-promotion).** The entries
below are carried over verbatim from the module's original CHANGELOG for
context. They predate this repo and are not `servicebus.v*` tags here.

## Version 1.1.1 (2026-08-11)

### Fixed

- **Network resource-group casing in the per-env defaults, which was planning a
  destroy/recreate of both private endpoints.** The `default_network` local
  introduced in 1.1.0 spelled the RG lowercase (`ftdc4-network-d` /
  `ftdc4-network-p`), but Azure — and therefore Terraform state from earlier
  applies — spells it `FTDC4-Network-D` / `FTDC4-Network-P`, the same casing
  `dns_resource_group_name` already used. Azure resource IDs are case-insensitive,
  so this looked cosmetic, but Terraform diffs `subnet_id` as a plain string and
  `subnet_id` is ForceNew on `azurerm_private_endpoint`. The next apply after 1.1.0
  would have replaced **both** the Service Bus and Key Vault private endpoints —
  new NICs, newly assigned private IPs, re-registered DNS A records, and a
  connectivity gap on the namespace and vault — with no functional change intended.
  The defaults now match Azure's casing, so the endpoints plan clean.
  - No action needed for deployments that never applied 1.1.0. If you did apply it,
    the endpoints were already replaced; confirm nothing pins their old private IPs.
  - Callers overriding `virtual_network_resource_group_name` must match Azure's
    exact casing for the same reason. Noted in the variable description and READMEs.

## Version 1.1.0 (2026-07-17)

Naming and usability changes from module review feedback. **All resource names
change** — this is a rename (destroy/recreate) for an already-deployed namespace,
so review the plan before applying.

### Changed

- **Naming convention** — the resource-type qualifier now goes **after** the base
  name (`{site}-{base_name}-{type}-{env}`) to match the FTDC4 / B2B standard:
  - Service Bus PE `ftdc4-pe-sbns-d` → `ftdc4-sbns-pe-d`
  - UAMI `ftdc4-uami-sbns-d` → `ftdc4-sbns-uami-d`
  - Key Vault `ftdc4-kv-sbns-d` → `ftdc4-sbns-kv-d`
  - Key Vault PE `ftdc4-pe-kv-sbns-d` → `ftdc4-sbns-kv-pe-d`
  - SAS rule / secret `ftdc4-sbns-d-sas-erp` → `ftdc4-sbns-sas-d-erp`
  - Geo-DR alias `ftdc4-sbns-d-geodr` → `ftdc4-sbns-geodr-d`
  - Namespace `ftdc4-sbns-d` is unchanged.
- **Environment normalization moved into the module.** `environment` now accepts
  any spelling (production/prod/p, development/dev/d, …) and is normalized to one of
  four canonical short codes — `p`, `d`, `s`, `t` — internally, so callers no longer
  reproduce the env map. The module also injects an overridable `Environment` tag
  derived from the normalized env.
  - **Aliases collapse onto the canonical codes:** `nonprod`/`np` → `d`, `qa`/`q` →
    `s`, `uat` → `t`. These are no longer distinct codes, so a `uat` deployment is
    now named and tagged exactly like `test` (`…-t`, `Test`), `np` like `dev`, and
    `qa` like `stage`. Any resources previously deployed under `-uat`, `-np` or `-q`
    names will rename (destroy/recreate) — review the plan.

### Added

- **Per-environment network defaults.** `virtual_network_name`,
  `virtual_network_resource_group_name` and `private_link_subnet_name` now default
  by environment (prod → production network; every non-prod env → shared development
  network), so most deployments omit them. Each remains independently overridable.
- **Key Vault name guarding.** The plan now fails fast with a clear message when the
  derived vault name would exceed Azure's 24-character limit or use invalid
  characters, instead of erroring opaquely at apply.
- `environment` output — the normalized short env code.

## Version 1.0.0 (2026-07-16)

Initial release.

### Features

- **Service Bus namespace** (Premium) with `public_network_access_enabled = false`
  and a private endpoint on the app subnet, resolving via the shared
  `privatelink.servicebus.windows.net` zone (referenced through the
  `azurerm.ftdc4-production` provider alias).
- **User-Assigned Managed Identity** granted `Azure Service Bus Data Sender` and
  `Azure Service Bus Data Receiver` on the namespace, for App Service
  `DefaultAzureCredential` auth.
- **Namespace-level SAS authorization rules** for on-prem/legacy apps — one per
  `onprem_sas_apps` entry.
- **Private, RBAC-authorized Key Vault** (private endpoint via
  `privatelink.vaultcore.azure.net`) storing each on-prem app's SAS connection
  string.
  - Terraform runner granted `Key Vault Secrets Officer` to write the secrets.
  - The UAMI granted `Key Vault Secrets User` to read them (mirrors the App
    Service managed-identity grant in `linux_app_service_internal`).
  - `time_sleep` guard for private-endpoint DNS propagation before data-plane
    writes, preventing first-apply 403 ForbiddenByConnection.
- **Geo-Disaster Recovery alias** (active/passive) — prod only, gated behind
  `geo_disaster_recovery_enabled` (default `false`).
- `private_dns_integration_enabled` toggle to deploy private endpoints before the
  network team has provisioned the privatelink DNS zones, then attach DNS
  registration later as an in-place update.

### Notes

- Authored in the shared-module style (flat layout, `.this` resource naming,
  `provider.tf` with `configuration_aliases` only, `MODULE_METADATA` header) so it
  could be promoted into `infra-workflow-shared` with minimal changes.
- Queues, topics and subscriptions are intentionally **not** managed here — entity
  provisioning is owned by the development teams that consume the namespace.
