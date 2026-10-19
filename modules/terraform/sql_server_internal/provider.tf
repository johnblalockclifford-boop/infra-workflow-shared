# Provider requirements for the sql_server_internal module.
#
# Declares only provider requirements (no backend, no provider configuration).
# The caller maps the azurerm.ftdc4-production alias to the provider for the
# subscription that holds the shared privatelink DNS zones. azuread reads the
# administrators group.
terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.ftdc4-production]
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}
