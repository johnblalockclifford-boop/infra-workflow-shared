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
  description = "The {base} segment of the database name: the workload name, the same base_name as the server's. Lowercase letters, digits and single hyphens."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.base_name))
    error_message = "Lowercase letters and digits, with single hyphens between them."
  }
}

variable "database_short_name" {
  description = "The database's own name segment, written after the sqldb type code: {site}-{base}-sqldb-{database_short_name}-{location}-{env}. Lowercase letters, digits and single hyphens."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.database_short_name))
    error_message = "Lowercase letters and digits, with single hyphens between them."
  }
}

variable "resource_group_name" {
  description = "Name of the existing resource group that holds the server. The module reads its region for the location segment of the database name."
  type        = string
}

variable "server_id" {
  description = "Resource ID of the SQL server the database goes on: sql_server_internal's server_id output."
  type        = string
  validation {
    condition     = var.server_id != null
    error_message = "server_id is null, so there is no server to put the database on in this environment. When the value is one(module.<server>[*].server_id), that server's module call creates nothing in this environment: set this environment to true in that call's live map."
  }
}

# ---------------------------------------------------------------------------
# Size and backups
# ---------------------------------------------------------------------------

variable "sku_name" {
  description = "The database's SKU, such as GP_S_Gen5_1 (General Purpose serverless, up to 1 vCore) or GP_Gen5_2 (General Purpose provisioned, 2 vCores). A serverless SKU (GP_S_*) pauses after auto_pause_delay_in_minutes without connections."
  type        = string
  default     = "GP_S_Gen5_1"
}

variable "max_size_gb" {
  description = "Maximum size of the database in GB."
  type        = number
  default     = 32
}

variable "auto_pause_delay_in_minutes" {
  description = "Serverless SKUs only: minutes without connections before the database pauses (and stops charging for compute), at least 15, or -1 to never pause. Ignored for other SKUs."
  type        = number
  default     = 60
  validation {
    condition     = var.auto_pause_delay_in_minutes == -1 || var.auto_pause_delay_in_minutes >= 15
    error_message = "Must be -1 or at least 15."
  }
}

variable "min_capacity" {
  description = "Serverless SKUs only: the fewest vCores the database keeps while it runs. Ignored for other SKUs."
  type        = number
  default     = 0.5
}

variable "backup_storage_redundancy" {
  description = "Redundancy of the database's backup storage: Geo, GeoZone, Local or Zone. Local keeps backups in one datacenter and costs least."
  type        = string
  default     = "Geo"
  validation {
    condition     = contains(["Geo", "GeoZone", "Local", "Zone"], var.backup_storage_redundancy)
    error_message = "Must be one of: Geo, GeoZone, Local, Zone."
  }
}

variable "short_term_retention_days" {
  description = "Days of point-in-time restore, 1 to 35."
  type        = number
  default     = 7
  validation {
    condition     = var.short_term_retention_days >= 1 && var.short_term_retention_days <= 35
    error_message = "Must be from 1 to 35."
  }
}

variable "collation" {
  description = "The database's collation. Azure cannot change it after creation: a new value replaces the database."
  type        = string
  default     = "SQL_Latin1_General_CP1_CI_AS"
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags for the database. The module adds Environment (the long form of the environment) unless this map sets it."
  type        = map(string)
  default     = {}
}
