# Provider requirements for the servicebus module.
#
# Like the other shared modules in this repo, it declares only provider
# *requirements* (no backend, no provider config) and takes the hub/production
# provider as a configuration alias so the caller wires it in explicitly.
terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = "~> 4.0"
      configuration_aliases = [azurerm.ftdc4-production]
    }

    # Used to let the Key Vault private endpoint's DNS record propagate before
    # writing SAS secrets to the vault data plane (see main.tf).
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}
