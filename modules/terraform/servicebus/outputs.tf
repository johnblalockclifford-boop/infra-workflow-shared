output "environment" {
  description = "The normalized short environment code used in resource names (e.g. 'd' for dev/development)"
  value       = local.env
}

output "namespace_id" {
  description = "The resource ID of the Service Bus namespace"
  value       = azurerm_servicebus_namespace.this.id
}

output "namespace_name" {
  description = "The name of the Service Bus namespace"
  value       = azurerm_servicebus_namespace.this.name
}

output "private_endpoint_ip" {
  description = "Private IP address of the Service Bus private endpoint"
  value       = var.private_endpoint_enabled ? azurerm_private_endpoint.servicebus[0].private_service_connection[0].private_ip_address : null
}

output "uami_client_id" {
  description = "Client ID of the User-Assigned Managed Identity (for DefaultAzureCredential)"
  value       = var.uami_enabled ? azurerm_user_assigned_identity.this[0].client_id : null
}

output "uami_principal_id" {
  description = "Principal (object) ID of the User-Assigned Managed Identity"
  value       = var.uami_enabled ? azurerm_user_assigned_identity.this[0].principal_id : null
}

output "key_vault_id" {
  description = "The resource ID of the Key Vault, if created"
  value       = var.key_vault_enabled ? azurerm_key_vault.this[0].id : null
}

output "key_vault_name" {
  description = "The name of the Key Vault, if created"
  value       = var.key_vault_enabled ? azurerm_key_vault.this[0].name : null
}

output "geo_dr_alias_id" {
  description = "Resource ID of the Geo-DR alias, if Geo-Disaster Recovery is enabled"
  value       = var.geo_disaster_recovery_enabled ? azurerm_servicebus_namespace_disaster_recovery_config.this[0].id : null
}

output "location" {
  description = "The location code (standard §2.2) used in resource names, derived from the resource group's region"
  value       = local.location
}
