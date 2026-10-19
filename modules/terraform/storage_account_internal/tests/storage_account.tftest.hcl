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
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ftdc4-dagit-d/providers/Microsoft.Storage/storageAccounts/ftdc4dagitdocsstncusd"
    }
  }
}

mock_provider "azurerm" {
  alias = "prod"
  mock_data "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/FTDC4-Network-P/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    }
  }
}

variables {
  environment         = "d"
  base_name           = "dagitdocs"
  resource_group_name = "ftdc4-dagit-d"
}

run "names_follow_the_naming_standard" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
  }

  assert {
    condition     = azurerm_storage_account.this.name == "ftdc4dagitdocsstncusd"
    error_message = "storage account name: ${azurerm_storage_account.this.name}"
  }
  assert {
    condition     = azurerm_private_endpoint.blob[0].name == "ftdc4-dagitdocs-st-pep-ncus-d"
    error_message = "private endpoint name: ${azurerm_private_endpoint.blob[0].name}"
  }
  assert {
    condition     = azurerm_private_endpoint.blob[0].private_service_connection[0].name == "ftdc4-dagitdocs-st-psc-ncus-d"
    error_message = "private service connection name"
  }
  assert {
    condition     = azurerm_private_endpoint.blob[0].private_dns_zone_group[0].name == "ftdc4-dagitdocs-st-dzg-ncus-d"
    error_message = "DNS zone group name"
  }
  assert {
    condition     = azurerm_private_endpoint.blob[0].private_service_connection[0].subresource_names == tolist(["blob"])
    error_message = "the private endpoint must target blob only"
  }
  assert {
    condition     = azurerm_storage_account.this.public_network_access_enabled == false
    error_message = "public network access must be off"
  }
  assert {
    condition     = azurerm_storage_account.this.tags["Environment"] == "Development"
    error_message = "Environment tag"
  }
  assert {
    condition     = data.azurerm_virtual_network.this.name == "FTDC4-Development1-D" && data.azurerm_subnet.private_link.name == "Dev-Application"
    error_message = "non-prod environments use the shared development network"
  }
}

run "prod_uses_the_production_network" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
  }
  variables {
    environment = "Production"
  }

  assert {
    condition     = azurerm_storage_account.this.name == "ftdc4dagitdocsstncusp"
    error_message = "storage account name: ${azurerm_storage_account.this.name}"
  }
  assert {
    condition     = data.azurerm_virtual_network.this.name == "FTDC4-Production1-P" && data.azurerm_virtual_network.this.resource_group_name == "FTDC4-Network-P" && data.azurerm_subnet.private_link.name == "Application"
    error_message = "prod uses the production network"
  }
}

run "only_base_is_shortened" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
  }
  variables {
    base_name = "a-very-long-workload-name"
  }

  assert {
    condition     = azurerm_storage_account.this.name == "ftdc4averylongworstncusd"
    error_message = "storage account name: ${azurerm_storage_account.this.name}"
  }
  assert {
    condition     = length(azurerm_storage_account.this.name) <= 24
    error_message = "longer than 24 characters"
  }
  assert {
    condition     = azurerm_private_endpoint.blob[0].name == "ftdc4-a-very-long-workload-name-st-pep-ncus-d"
    error_message = "the private endpoint keeps base in full"
  }
}

run "an_unregistered_region_fails_the_plan" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
  }
  override_data {
    target = data.azurerm_resource_group.this
    values = {
      location = "westeurope"
    }
  }
  expect_failures = [azurerm_storage_account.this]
}

run "read_access_replication_is_rejected" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
  }
  variables {
    account_replication_type = "RAGRS"
  }
  expect_failures = [var.account_replication_type]
}

run "without_dns_integration_the_endpoint_has_no_zone_group" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
  }
  variables {
    private_dns_integration_enabled = false
  }

  assert {
    condition     = length(azurerm_private_endpoint.blob[0].private_dns_zone_group) == 0
    error_message = "no zone group expected"
  }
  assert {
    condition     = length(data.azurerm_private_dns_zone.blob) == 0
    error_message = "no zone lookup expected"
  }
}

run "role_assignments_follow_the_maps" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
  }
  variables {
    blob_data_contributors = { api = "11111111-1111-1111-1111-111111111111" }
    blob_data_readers      = { reports = "22222222-2222-2222-2222-222222222222" }
  }

  assert {
    condition     = azurerm_role_assignment.blob_data_contributor["api"].role_definition_name == "Storage Blob Data Contributor"
    error_message = "contributor role"
  }
  assert {
    condition     = azurerm_role_assignment.blob_data_reader["reports"].principal_id == "22222222-2222-2222-2222-222222222222"
    error_message = "reader principal"
  }
}

run "name_short_names_the_storage_account_only" {
  command = plan
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.prod
  }
  variables {
    base_name  = "informaticasa-docs"
    name_short = "informatdocs"
  }

  assert {
    condition     = azurerm_storage_account.this.name == "ftdc4informatdocsstncusd"
    error_message = "storage account name: ${azurerm_storage_account.this.name}"
  }
  assert {
    condition     = azurerm_private_endpoint.blob[0].name == "ftdc4-informaticasa-docs-st-pep-ncus-d"
    error_message = "private endpoint name: ${azurerm_private_endpoint.blob[0].name}"
  }
}
