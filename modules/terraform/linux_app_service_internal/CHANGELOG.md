# Changelog for linux_app_service_internal

## Version 0.0.2 (2026-03-10T21:58:56.548279)

## Version 1.2.3 (2026-03-26T14:10:36.711225)

## Version 1.2.3 (2026-03-26T14:37:49.155474)

## Version 1.2.3 (2026-03-26T15:02:10.949087)

## Version 1.2.6 (2026-03-26T15:07:26.172859)

## Version 1.2.7 (2026-03-26T15:57:46.290219)

## Version 1.2.8 (2026-03-31T20:52:16.535452)

## Version 1.2.9 (2026-03-31T22:36:31.369960)

## Version 1.2.10 (2026-03-31T23:02:36.746703)

## Version 1.2.11 (2026-04-01T13:54:44.959707)

## Version 1.2.12 (2026-05-04T20:53:41.783599)

## Version 1.2.13 (2026-06-04T14:26:32.117350)

## Version 1.2.14 (2026-06-11T21:13:45.677683)

## Version 1.2.15 (2026-06-11T21:55:34.795989)

## Version 1.2.16 (2026-06-11T22:29:46.811331)

## Version 1.2.17 (2026-06-12T13:42:16.176875)

## Version 1.2.18 (2026-06-12T15:29:38.312558)

## Version 1.2.19 (2026-07-01T21:23:31.212362)

## Version 1.2.20 (2026-07-01T22:00:36.883737)

## Version 1.2.21 (2026-07-02T13:51:23.354746)

- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- No specific changes logged
- fix: update comment to clarify module versioning and release automation issues
- Update module metadata after version release [skip ci]
- fix: correct regex validation for site variable to allow multiple characters
- fix: correct regex validation for site variable to allow multiple characters
- Update module metadata after version release [skip ci]
- No specific changes logged
- No specific changes logged

## Version 1.2.19 (2026-07-01)

### ⚠ BREAKING CHANGES

- **`implicit_grant_access_token_issuance_enabled` default changed to `false`.**
  Previously `true`. Easy Auth uses PKCE/auth-code flow and does not require implicit grant.
  If your application explicitly needs implicit grant tokens (legacy SPA), set this to `true`.

- **`implicit_grant_id_token_issuance_enabled` default changed to `false`.**
  Same rationale as above.

### Features

- **Zero-config Easy Auth**: `auth_settings_v2 = {}` now fully mirrors the Azure Portal's
  "Add identity provider" flow — no separate client ID or secret management required.
  - `active_directory_v2.client_id` is now optional; defaults to the module-created app registration.
  - Client secret (`azuread_application_password`) is created automatically and stored in Key Vault.
  - `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` is wired as a Key Vault reference app setting.
  - Token store enabled by default (`token_store_enabled = true`).
  - Logout endpoint set to `/.auth/logout` by default.
  - Forward proxy convention set to `Standard` by default (correct for internal apps behind LBs).
  - `api://<client-id>` automatically added to `allowed_audiences`.
- **`sign_in_audience = "AzureADMyOrg"`** now set explicitly on the app registration.
- New `manage_client_secret` option in `auth_settings_v2` to opt out of module-managed secret
  (useful when using an external app registration or a custom rotation process).
- New outputs: `auth_client_secret_kv_secret_name`, `auth_client_secret_kv_secret_id`.
- New role assignment: `Key Vault Secrets Officer` granted to the Terraform runner when
  the module manages the auth client secret.
- Removed garbage config content accidentally appended to README.md.

---

## Version 1.2.18 (2026-06-12)

### ⚠ POTENTIAL BREAKING CHANGES

- **Private endpoint and private service connection names for Key Vault and Storage Account have changed.**
  The names are now derived from the same logic used to generate the Key Vault / Storage Account
  resource names themselves (hyphens stripped from `base_name`, and `base_name` truncated if the
  total would exceed Azure's 24-character limit). This makes PE/PSC names consistent with the
  resources they front.

  **Impact:** Terraform will plan a destroy and recreate of the following resources for any existing
  deployment:
  - `azurerm_private_endpoint.keyvault`
  - `azurerm_private_endpoint.storageaccount`
  - And their corresponding `private_service_connection` blocks

  Recreating private endpoints is generally not majorly disruptive — the underlying Key Vault and
  Storage Account are not affected — but there will be a brief window during recreation where
  private connectivity to those resources is interrupted. Plan for minor downtime on the
  application during the apply.

  **No action is required** unless you have external references (e.g. DNS overrides, NSG rules, or
  monitoring alerts) that target the private endpoint resource names directly, in which case those
  should be updated after apply.