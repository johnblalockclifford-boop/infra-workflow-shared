# Plans the module against mock providers: no Azure credentials, no network.
# Run from the module directory: tofu init, then tofu test (or terraform test).

mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      location = "northcentralus"
    }
  }
  mock_data "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/FTDC4-Network-D/providers/Microsoft.Network/virtualNetworks/FTDC4-Development1-D/subnets/Dev-Application"
    }
  }
  mock_resource "azurerm_mssql_server" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ftdc4-dagit-d/providers/Microsoft.Sql/servers/ftdc4-dagit-sql-ncus-d"
    }
  }
}

mock_provider "azurerm" {
  alias = "prod"
  mock_data "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/FTDC4-Network-P/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net"
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_group" {
    defaults = {
      object_id = "33333333-3333-3333-3333-333333333333"
    }
  }
}

variables {
  environment              = "d"
  base_name                = "dagit"
  resource_group_name      = "ftdc4-dagit-d"
  administrator_group_name = "SG-Dagit-SQL-Admins"
}

run "names_follow_the_naming_standard" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
    azuread                  = azuread
  }

  assert {
    condition     = azurerm_mssql_server.this.name == "ftdc4-dagit-sql-ncus-d"
    error_message = "server name: ${azurerm_mssql_server.this.name}"
  }
  assert {
    condition     = azurerm_private_endpoint.sql[0].name == "ftdc4-dagit-sql-pep-ncus-d"
    error_message = "private endpoint name: ${azurerm_private_endpoint.sql[0].name}"
  }
  assert {
    condition     = azurerm_private_endpoint.sql[0].private_service_connection[0].subresource_names == tolist(["sqlServer"])
    error_message = "the private endpoint must target sqlServer"
  }
  assert {
    condition     = azurerm_private_endpoint.sql[0].private_dns_zone_group[0].name == "ftdc4-dagit-sql-dzg-ncus-d"
    error_message = "DNS zone group name"
  }
}

run "entra_only_with_the_named_group" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
    azuread                  = azuread
  }

  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].azuread_authentication_only == true
    error_message = "Entra ID authentication only"
  }
  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].object_id == "33333333-3333-3333-3333-333333333333"
    error_message = "administrator group object ID"
  }
  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].login_username == "SG-Dagit-SQL-Admins"
    error_message = "administrator login name"
  }
  assert {
    condition     = azurerm_mssql_server.this.public_network_access_enabled == false
    error_message = "public network access must be off"
  }
  assert {
    condition     = azurerm_mssql_server.this.minimum_tls_version == "1.2"
    error_message = "minimum TLS version"
  }
}

run "prod_uses_the_production_network" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
    azuread                  = azuread
  }
  variables {
    environment = "prod"
  }

  assert {
    condition     = azurerm_mssql_server.this.name == "ftdc4-dagit-sql-ncus-p"
    error_message = "server name: ${azurerm_mssql_server.this.name}"
  }
  assert {
    condition     = data.azurerm_virtual_network.this.name == "FTDC4-Production1-P" && data.azurerm_subnet.private_link.name == "Application"
    error_message = "prod uses the production network"
  }
}

run "an_empty_group_name_is_rejected" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
    azuread                  = azuread
  }
  variables {
    administrator_group_name = "  "
  }
  expect_failures = [var.administrator_group_name]
}

run "an_unregistered_region_fails_the_plan" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
    azuread                  = azuread
  }
  override_data {
    target = data.azurerm_resource_group.this
    values = {
      location = "westeurope"
    }
  }
  expect_failures = [azurerm_mssql_server.this]
}
