# App Service Outputs
output "app_service_name" {
  description = "Name of the Linux App Service"
  value       = azurerm_linux_web_app.this.name
}

output "app_service_id" {
  description = "Resource ID of the Linux App Service"
  value       = azurerm_linux_web_app.this.id
}

output "app_service_default_hostname" {
  description = "Default hostname of the App Service"
  value       = azurerm_linux_web_app.this.default_hostname
}

output "app_service_principal_id" {
  description = "Principal ID of the App Service managed identity"
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}

# Container Registry Outputs
output "container_registry_login_server" {
  description = "Login server URL of the Container Registry"
  value       = azurerm_container_registry.this.login_server
}

output "container_registry_admin_username" {
  description = "Admin username for the Container Registry"
  value       = azurerm_container_registry.this.admin_username
  sensitive   = true
}

output "container_registry_admin_password" {
  description = "Admin password for the Container Registry"
  value       = azurerm_container_registry.this.admin_password
  sensitive   = true
}

output "container_registry_id" {
  description = "Resource ID of the Container Registry"
  value       = azurerm_container_registry.this.id
}

# Key Vault Outputs
output "key_vault_id" {
  description = "Resource ID of the Key Vault"
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.this.vault_uri
}

# Storage Account Outputs
output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.this.name
}

output "storage_account_id" {
  description = "Resource ID of the Storage Account"
  value       = azurerm_storage_account.this.id
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

# Service Plan Output
output "service_plan_id" {
  description = "Resource ID of the App Service Plan"
  value       = azurerm_service_plan.this.id
}

# Custom Domain Outputs (Optional)
output "custom_domain_url" {
  description = "Full URL of the custom domain (if configured)"
  value       = local.deploy_custom_domain ? "https://${azurerm_app_service_custom_hostname_binding.custom_hostname[0].hostname}" : null
}

output "custom_domain_certificate_thumbprint" {
  description = "Thumbprint of the custom domain certificate (if configured)"
  value       = local.deploy_custom_domain ? azurerm_app_service_managed_certificate.custom_cert[0].thumbprint : null
}

# Azure AD Application Outputs
output "azuread_application_id" {
  description = "Application (client) ID of the Azure AD application"
  value       = azuread_application.app.client_id
}

output "azuread_application_object_id" {
  description = "Object ID of the Azure AD application"
  value       = azuread_application.app.object_id
}

output "azuread_service_principal_object_id" {
  description = "Object ID of the Azure AD service principal"
  value       = azuread_service_principal.sp.object_id
}

# Auth Client Secret Outputs (only populated when auth_settings_v2 is set and the module manages the secret)
output "auth_client_secret_kv_secret_name" {
  description = "Name of the Key Vault secret holding the Easy Auth client secret. Null when auth is disabled or manage_client_secret = false."
  value       = local._manage_auth_secret ? azurerm_key_vault_secret.auth_client_secret[0].name : null
}

output "auth_client_secret_kv_secret_id" {
  description = "Versionless Key Vault secret URI for the Easy Auth client secret. Null when auth is disabled or manage_client_secret = false."
  value       = local._manage_auth_secret ? azurerm_key_vault_secret.auth_client_secret[0].versionless_id : null
}
