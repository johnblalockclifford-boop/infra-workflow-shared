output "environment" {
  description = "The short environment code used in the database name (e.g. 'd' for dev/development)"
  value       = local.env
}

output "location" {
  description = "The location code (standard §2.2) used in the database name, read from the resource group's region"
  value       = local.location
}

output "database_id" {
  description = "The resource ID of the database"
  value       = azurerm_mssql_database.this.id
}

output "database_name" {
  description = "The name of the database, for connection strings"
  value       = azurerm_mssql_database.this.name
}
