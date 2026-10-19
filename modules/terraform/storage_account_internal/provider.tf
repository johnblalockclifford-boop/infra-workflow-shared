# Provider requirements for the storage_account_internal module.
#
# Like the other shared modules in this repo, it declares only provider
# requirements (no backend, no provider configuration). The caller maps the
# azurerm.ftdc4-production alias to the provider for the subscription that
# holds the shared privatelink DNS zones.
terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.ftdc4-production]
    }
  }
}
