# Plans the module against a mock provider: no Azure credentials, no network.
# Run from the module directory: tofu init, then tofu test (or terraform test).

mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      location = "northcentralus"
    }
  }
}

variables {
  environment         = "d"
  base_name           = "dagit"
  database_short_name = "orders"
  resource_group_name = "ftdc4-dagit-d"
  server_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ftdc4-dagit-d/providers/Microsoft.Sql/servers/ftdc4-dagit-sql-ncus-d"
}

run "name_follows_the_naming_standard" {
  command = plan

  assert {
    condition     = azurerm_mssql_database.this.name == "ftdc4-dagit-sqldb-orders-ncus-d"
    error_message = "database name: ${azurerm_mssql_database.this.name}"
  }
  assert {
    condition     = azurerm_mssql_database.this.tags["Environment"] == "Development"
    error_message = "Environment tag"
  }
}

run "serverless_sets_auto_pause_and_min_capacity" {
  command = plan

  assert {
    condition     = azurerm_mssql_database.this.sku_name == "GP_S_Gen5_1"
    error_message = "default SKU"
  }
  assert {
    condition     = azurerm_mssql_database.this.auto_pause_delay_in_minutes == 60 && azurerm_mssql_database.this.min_capacity == 0.5
    error_message = "serverless settings"
  }
}

run "a_provisioned_sku_plans" {
  command = plan
  variables {
    sku_name = "GP_Gen5_2"
  }

  # min_capacity and auto_pause_delay_in_minutes are computed attributes the
  # module leaves null for a provisioned SKU; a plan cannot read them, so the
  # run checks only that the SKU plans.
  assert {
    condition     = azurerm_mssql_database.this.sku_name == "GP_Gen5_2"
    error_message = "SKU"
  }
}

run "backup_redundancy_and_retention" {
  command = plan
  variables {
    backup_storage_redundancy = "Local"
    short_term_retention_days = 14
  }

  assert {
    condition     = azurerm_mssql_database.this.storage_account_type == "Local"
    error_message = "backup storage redundancy"
  }
  assert {
    condition     = azurerm_mssql_database.this.short_term_retention_policy[0].retention_days == 14
    error_message = "retention days"
  }
}

run "a_null_server_id_is_rejected" {
  command = plan
  variables {
    server_id = null
  }
  expect_failures = [var.server_id]
}

run "an_unknown_backup_redundancy_is_rejected" {
  command = plan
  variables {
    backup_storage_redundancy = "LRS"
  }
  expect_failures = [var.backup_storage_redundancy]
}
