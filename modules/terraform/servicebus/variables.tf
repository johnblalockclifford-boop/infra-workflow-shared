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
  description = "Workload/application name (the {base} segment of {site}-{base}-{type}-{location}-{env}). Lowercase letters, digits and single hyphens. This is the only segment shortened to satisfy length limits (Key Vault: 24 chars)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.base_name))
    error_message = "Lowercase letters and digits, with single hyphens between them."
  }
}

variable "name_short" {
  description = "Short form of base_name (6 characters or fewer recommended) used in place of base_name for length-constrained resources such as the Key Vault. If the name is still too long it is truncated. Defaults to base_name."
  type        = string
  default     = null
  validation {
    condition     = var.name_short == null || can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.name_short))
    error_message = "Lowercase letters and digits, with single hyphens between them."
  }
}

variable "resource_group_name" {
  description = "Name of the existing resource group the resources are created in. Referenced (must already exist), not created."
  type        = string
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "virtual_network_name" {
  description = "Name of the existing application Virtual Network that hosts the private endpoint subnet. Defaults to the prod network (FTDC4-Production1-P) for prod and the shared development network (FTDC4-Development1-D) for every non-prod environment. Set to override."
  type        = string
  default     = null
}

variable "virtual_network_resource_group_name" {
  description = "Resource group that contains the existing application Virtual Network. Defaults to FTDC4-Network-P for prod and FTDC4-Network-D for every non-prod environment. Set to override — and match Azure's exact casing when you do: subnet_id is ForceNew, so a casing-only difference from state replaces both private endpoints."
  type        = string
  default     = null
}

variable "private_link_subnet_name" {
  description = "Name of the existing subnet used for the Service Bus and Key Vault private endpoints. Defaults to 'Application' for prod and 'Dev-Application' for every non-prod environment. Set to override."
  type        = string
  default     = null
}

variable "private_endpoint_enabled" {
  description = "Whether to create the private endpoints and DNS integration"
  type        = bool
  default     = true
}

variable "dns_resource_group_name" {
  description = "Resource group (in the production hub subscription) that holds the shared privatelink DNS zones."
  type        = string
  default     = "FTDC4-Network-P"
}

variable "private_dns_integration_enabled" {
  description = "Whether to look up the shared privatelink DNS zones and attach a private_dns_zone_group to each private endpoint. Set false to deploy the endpoints before the network team has provisioned the DNS zones; flip to true later to add DNS registration as an in-place update (no endpoint rebuild)."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Service Bus namespace sizing
# ---------------------------------------------------------------------------

variable "sku" {
  description = "SKU for the Service Bus namespace (Premium is required for private endpoints)"
  type        = string
  default     = "Premium"
}

variable "capacity" {
  description = "Messaging units for the Premium namespace (1, 2, 4, 8 or 16)"
  type        = number
  default     = 1
}

variable "premium_messaging_partitions" {
  description = "Number of messaging partitions (Premium only)"
  type        = number
  default     = 1
}

variable "public_network_access_enabled" {
  description = "Whether public network access is allowed to the namespace. Must be false for the private-only architecture."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Geo-Disaster Recovery (active/passive) — prod only. Off by default so dev is
# unaffected. See main.tf.
# ---------------------------------------------------------------------------

variable "geo_disaster_recovery_enabled" {
  description = "Enable Geo-Disaster Recovery (active/passive namespace pairing via an alias). Prod only — requires a partner Premium namespace in the paired region. Leave false for dev."
  type        = bool
  default     = false
}

variable "geo_dr_alias_name" {
  description = "Alias name for the Geo-DR pairing (clients connect to this so failover is transparent). Defaults to {site}-{base}-geodr-{location}-{env} when omitted."
  type        = string
  default     = null
}

variable "geo_dr_partner_namespace_id" {
  description = "Resource ID of the secondary (partner) Service Bus namespace in the paired region. Required when geo_disaster_recovery_enabled is true."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Authentication
#
# NOTE: Queues, topics and subscriptions (and their TTL / lock / delivery
# settings) are intentionally NOT managed here. Entity provisioning is owned by
# the development teams that consume the namespace.
# ---------------------------------------------------------------------------

variable "uami_enabled" {
  description = "Whether to create the User-Assigned Managed Identity and grant it Service Bus data-plane roles"
  type        = bool
  default     = true
}

variable "onprem_sas_apps" {
  description = "On-prem apps that authenticate with a SAS token. Each entry creates a namespace authorization rule and stores its connection string in Key Vault as {site}-{base}-sas-{key}-{location}-{env} (e.g. ftdc4-myapp-sas-erp-ncus-d)."
  type = map(object({
    listen = optional(bool, true)
    send   = optional(bool, true)
    manage = optional(bool, false)
  }))
  default = {}
}

# ---------------------------------------------------------------------------
# Key Vault (private-only, one per environment)
# ---------------------------------------------------------------------------

variable "key_vault_enabled" {
  description = "Whether to create a Key Vault for the environment"
  type        = bool
  default     = true
}

variable "key_vault_sku_name" {
  description = "SKU for the Key Vault"
  type        = string
  default     = "standard"
}

variable "key_vault_soft_delete_days" {
  description = "Soft delete retention in days for the Key Vault"
  type        = number
  default     = 7
}

variable "key_vault_purge_protection_enabled" {
  description = "Whether to enable purge protection on the Key Vault (recommended for prod)"
  type        = bool
  default     = false
}

variable "key_vault_network_acls_ip_rules" {
  description = "CIDR ranges allowed through the Key Vault firewall in addition to the private endpoint. Use to allowlist the Terraform runner's egress IP so it can write SAS secrets when the vault is private. Empty = private endpoint only."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
