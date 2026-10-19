# Changelog for storage_account_internal

## Unreleased — First release

Written for the infra-ops Storage Account request type, in the servicebus
module's style. Release it as `v1.0.0` (`.setver t-storage_account_internal v1.0.0`
on the pull request): infra-ops pins that version.

### Added

- Private-only StorageV2 account: public network access off, TLS 1.2, no
  anonymous blob access, blob and container soft delete (7 days by default).
- Blob private endpoint on the application subnet, registered in the shared
  `privatelink.blob.core.windows.net` zone through the `azurerm.ftdc4-production`
  alias. Network defaults by environment, as in servicebus.
- Names per the Resource Naming Standard: `{site}{base}st{location}{env}` for the
  account, `{site}-{base}-st-pep|psc|dzg-{location}-{env}` for the endpoint.
  `name_short`, when set, takes base's place in the account name only.
- `blob_data_contributors` and `blob_data_readers` role assignment maps.
- Mock-provider tests in `tests/`.
