# Changelog for sql_database_internal

## Unreleased — First release

Written for the infra-ops SQL Database request type. Release it as `v1.0.0`
(`.setver t-sql_database_internal v1.0.0` on the pull request): infra-ops pins
that version.

### Added

- One Azure SQL database on a `sql_server_internal` server: SKU (default
  `GP_S_Gen5_1`, serverless, pausing after 60 idle minutes), maximum size,
  backup storage redundancy, and point-in-time restore retention.
- A null `server_id` fails the plan with a message pointing at the server's
  `live` map.
- Names per the Resource Naming Standard:
  `{site}-{base}-sqldb-{database_short_name}-{location}-{env}`.
- Mock-provider tests in `tests/`.
