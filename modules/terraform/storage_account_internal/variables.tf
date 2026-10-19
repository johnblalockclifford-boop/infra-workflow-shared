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
  description = "The {base} segment of the resource names. Lowercase letters, digits and single hyphens. The private endpoint names keep it in full. The storage account name is built from name_short when set, else from base_name: hyphens dropped, and as many characters as fit in 24 after site, the st type code, location and env (12 for ftdc4 in ncus with a one-letter env)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.base_name))
    error_message = "Lowercase letters and digits, with single hyphens between them."
  }
}

variable "name_short" {
  description = "Used in place of base_name for the storage account name, the only name with a tight length limit. Lowercase letters, digits and single hyphens; the hyphens are dropped. If it is still too long, it is truncated. Defaults to base_name."
  type        = string
  default     = null
  validation {
    condition     = var.name_short == null || can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.name_short))
    error_message = "Lowercase letters and digits, with single hyphens between them."
  }
}

variable "resource_group_name" {
  description = "Name of the existing resource group the storage account and its private endpoint go in. The module reads it (it must already exist) and takes the location from it."
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
  description = "Name of the existing subnet the blob private endpoint goes in. Defaults to Application for prod and Dev-Application for every other environment."
  type        = string
  default     = null
}

variable "private_endpoint_enabled" {
  description = "Whether to create the blob private endpoint."
  type        = bool
  default     = true
}

variable "dns_resource_group_name" {
  description = "Resource group, in the subscription the azurerm.ftdc4-production provider reaches, that holds the shared privatelink.blob.core.windows.net zone."
  type        = string
  default     = "FTDC4-Network-P"
}

variable "private_dns_integration_enabled" {
  description = "Whether to read the shared privatelink.blob.core.windows.net zone and attach a private_dns_zone_group to the private endpoint. Set false to create the endpoint before the network team has the zone; setting it true later is an in-place update."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Storage account
# ---------------------------------------------------------------------------

variable "account_replication_type" {
  description = "Replication of the storage account: LRS, ZRS, GRS or GZRS. The read-access variants (RA-GRS, RA-GZRS) are not offered: reading the secondary privately needs a second private endpoint this module does not create."
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS"], var.account_replication_type)
    error_message = "Must be one of: LRS, ZRS, GRS, GZRS."
  }
}

variable "access_tier" {
  description = "Default access tier for blobs: Hot or Cool."
  type        = string
  default     = "Hot"
  validation {
    condition     = contains(["Hot", "Cool"], var.access_tier)
    error_message = "Must be Hot or Cool."
  }
}

variable "shared_access_key_enabled" {
  description = "Whether the storage account accepts its access keys and SAS tokens signed with them. Setting false leaves Entra ID (RBAC) as the only way in, and requires storage_use_azuread = true in the caller's azurerm provider block, because the provider reads the account's data plane while it plans."
  type        = bool
  default     = true
}

variable "blob_delete_retention_days" {
  description = "Days a deleted blob stays recoverable (blob soft delete), 1 to 365."
  type        = number
  default     = 7
  validation {
    condition     = var.blob_delete_retention_days >= 1 && var.blob_delete_retention_days <= 365
    error_message = "Must be from 1 to 365."
  }
}

variable "container_delete_retention_days" {
  description = "Days a deleted container stays recoverable (container soft delete), 1 to 365."
  type        = number
  default     = 7
  validation {
    condition     = var.container_delete_retention_days >= 1 && var.container_delete_retention_days <= 365
    error_message = "Must be from 1 to 365."
  }
}

variable "blob_versioning_enabled" {
  description = "Whether the storage account keeps previous versions of overwritten blobs."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Access
# ---------------------------------------------------------------------------

variable "blob_data_contributors" {
  description = "Principals granted Storage Blob Data Contributor on the storage account, as { <key> = <principal (object) ID> }. The key is any fixed name, such as the consuming app; it keeps the role assignment's address stable when the principal ID is only known after apply."
  type        = map(string)
  default     = {}
}

variable "blob_data_readers" {
  description = "Principals granted Storage Blob Data Reader on the storage account, as { <key> = <principal (object) ID> }."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags for every resource. The module adds Environment (the long form of the environment) unless this map sets it."
  type        = map(string)
  default     = {}
}
