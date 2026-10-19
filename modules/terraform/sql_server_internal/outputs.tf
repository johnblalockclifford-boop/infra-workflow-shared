output "environment" {
  description = "The short environment code used in resource names (e.g. 'd' for dev/development)"
  value       = local.env
}

output "location" {
  description = "The location code (standard §2.2) used in resource names, read from the resource group's region"
  value       = local.location
}

output "server_id" {
  description = "The resource ID of the SQL server. Pass it to sql_database_internal's server_id."
  value       = azurerm_mssql_server.this.id
}

output "server_name" {
  description = "The name of the SQL server"
  value       = azurerm_mssql_server.this.name
}

output "fully_qualified_domain_name" {
  description = "The server's host name (<name>.database.windows.net). Inside the network it resolves to the private endpoint's address through the shared privatelink zone."
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "administrator_group_object_id" {
  description = "Object ID of the Entra ID group that administers the server"
  value       = data.azuread_group.administrators.object_id
}

output "private_endpoint_ip" {
  description = "Private IP address of the SQL server's private endpoint, or null when private_endpoint_enabled is false"
  value       = var.private_endpoint_enabled ? azurerm_private_endpoint.sql[0].private_service_connection[0].private_ip_address : null
}
