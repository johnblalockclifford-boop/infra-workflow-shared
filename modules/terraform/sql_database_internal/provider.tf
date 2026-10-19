# Provider requirements for the sql_database_internal module.
#
# Declares only provider requirements (no backend, no provider configuration).
# The database sits on a server sql_server_internal created, and reaches the
# network through that server's private endpoint, so this module needs no DNS
# provider alias.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
