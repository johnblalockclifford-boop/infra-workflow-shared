output "environment" {
  description = "The short environment code used in resource names (e.g. 'd' for dev/development)"
  value       = local.env
}

output "location" {
  description = "The location code (standard §2.2) used in resource names, read from the resource group's region"
  value       = local.location
}

output "storage_account_id" {
  description = "The resource ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "The blob endpoint URL. Inside the network it resolves to the private endpoint's address through the shared privatelink zone."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "private_endpoint_ip" {
  description = "Private IP address of the blob private endpoint, or null when private_endpoint_enabled is false"
  value       = var.private_endpoint_enabled ? azurerm_private_endpoint.blob[0].private_service_connection[0].private_ip_address : null
}
