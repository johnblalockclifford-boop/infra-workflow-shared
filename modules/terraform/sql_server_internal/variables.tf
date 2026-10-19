# ---------------------------------------------------------------------------
# Site and Environment
# ---------------------------------------------------------------------------

variable "site" {
  description = "Site a.k.a. Data Center (e.g., 'ftdc4')"
  type        = string
  default     = "ftdc4"
  validation {
    condition     = can(regex("^[a-z0-9]+$", var.site))
    error_message = "Lowercase letters and numbers only."
  }
}

variable "environment" {
  description = "Environment name per the FTI Resource Naming Standard §2.3. Accepts the short, medium or long spelling (case-insensitive) and normalizes to the short code used in every resource name: p (prod/production), d (dev/development), s (stage), t (test), u (uat), q (qa), x (sbx/sandbox). No other aliases are accepted."
  type        = string
  validation {
    condition = contains([
      "p", "prod", "production",
      "d", "dev", "development",
      "s", "stage",
      "t", "test",
      "u", "uat",
      "q", "qa",
      "x", "sbx", "sandbox",
    ], lower(var.environment))
    error_message = "Must be one of: p/prod/production, d/dev/development, s/stage, t/test, u/uat, q/qa, x/sbx/sandbox."
  }
}

variable "base_name" {
  description = "The {base} segment of the resource names: the workload name. Lowercase letters, digits and single hyphens. The server name keeps as much of base as fits in 63 characters."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.base_name))
    error_message = "Lowercase letters and digits, with single hyphens between them."
  }
}

variable "resource_group_name" {
  description = "Name of the existing resource group the SQL server and its private endpoint go in. The module reads it (it must already exist) and takes the location from it."
  type        = string
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "virtual_network_name" {
  description = "Name of the existing Virtual Network that holds the private endpoint subnet. Defaults to FTDC4-Production1-P for prod and FTDC4-Development1-D for every other environment."
  type        = string
  default     = null
}

variable "virtual_network_resource_group_name" {
  description = "Resource group of that Virtual Network. Defaults to FTDC4-Network-P for prod and FTDC4-Network-D for every other environment. Match Azure's exact casing: subnet_id is ForceNew on azurerm_private_endpoint, so a casing-only difference from state replaces the private endpoint."
  type        = string
  default     = null
}

variable "private_link_subnet_name" {
  description = "Name of the existing subnet the SQL server's private endpoint goes in. Defaults to Application for prod and Dev-Application for every other environment."
  type        = string
  default     = null
}

variable "private_endpoint_enabled" {
  description = "Whether to create the SQL server's private endpoint."
  type        = bool
  default     = true
}

variable "dns_resource_group_name" {
  description = "Resource group, in the subscription the azurerm.ftdc4-production provider reaches, that holds the shared privatelink.database.windows.net zone."
  type        = string
  default     = "FTDC4-Network-P"
}

variable "private_dns_integration_enabled" {
  description = "Whether to read the shared privatelink.database.windows.net zone and attach a private_dns_zone_group to the private endpoint. Set false to create the endpoint before the network team has the zone; setting it true later is an in-place update."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Administrators
# ---------------------------------------------------------------------------

variable "administrator_group_name" {
  description = "Display name of the Entra ID security group that administers the server. The module reads the group through the azuread provider, so the identity running the plan needs to read groups (Group.Read.All or Directory.Read.All in Microsoft Graph). The server accepts Entra ID sign-ins only: it has no SQL administrator login."
  type        = string
  validation {
    condition     = length(trimspace(var.administrator_group_name)) > 0
    error_message = "Must not be empty."
  }
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags for every resource. The module adds Environment (the long form of the environment) unless this map sets it."
  type        = map(string)
  default     = {}
}
