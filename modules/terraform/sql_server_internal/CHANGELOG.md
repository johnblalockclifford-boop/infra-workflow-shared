# Changelog for sql_server_internal

## Unreleased — First release

Written for the infra-ops SQL Database request type, in the servicebus module's
style. Release it as `v1.0.0` (`.setver t-sql_server_internal v1.0.0` on the pull
request): infra-ops pins that version.

### Added

- Private-only Azure SQL logical server (12.0, TLS 1.2, public network access
  off) with Entra ID-only authentication. The Entra ID security group named in
  `administrator_group_name` is its administrator; the server has no SQL login.
- Private endpoint (`sqlServer`) on the application subnet, registered in the
  shared `privatelink.database.windows.net` zone through the
  `azurerm.ftdc4-production` alias. Network defaults by environment, as in
  servicebus.
- Names per the Resource Naming Standard: `{site}-{base}-sql-{location}-{env}`.
- Mock-provider tests in `tests/`.
