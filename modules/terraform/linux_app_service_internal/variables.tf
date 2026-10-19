variable "site" {
  description = "Site a.k.a. Data Center, .e.g. 'ftdc4'"
  validation {
    condition     = can(regex("^[a-z0-9]+$", var.site))
    error_message = "Lowercase letters and numbers only."
  }
}

variable "environment" {
  description = "Environment (short, eg., `p` for prod, `d` for dev)"

  # must match the values in the local env mapping tables
  validation {
    condition     = can(regex("^(p|d|s|t|uat|np|q)$", var.environment))
    error_message = "Environment must be one of: p, d, s, t, uat, np, q."
  }
}

variable "base_name" {
  description = "Base name for resources (e.g., 'myapp')"
}

variable "resource_group_name" {
  description = "Name of the resource group where the app service resources will be created"
}

# Network Variables
variable "virtual_network_name" {
  description = "Name of the Virtual Network"
}

variable "virtual_network_resource_group_name" {
  description = "Resource Group name of the Virtual Network"
}

variable "private_link_subnet_name" {
  description = "Name of the Subnet for Private Link endpoints"
}

variable "vnet_integration_subnet_name" {
  description = "Name of the Subnet for VNet Integration"
  default     = "appservice-shared-vnet-integration"
}

# App Service Variables

variable "app_service_sku" {
  description = "App Service Plan SKU - Production requires a premium sku"
  default     = "P0v4"
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
}

variable "custom_fqdn" {
  description = "Fully qualified custom hostname for the application (e.g., 'myapp.faithtechinc.com'). The host and domain portions are split automatically into locals. Leave empty to skip custom domain configuration."
  type        = string
  default     = ""
}

variable "base_domain_labels" {
  description = "Number of DNS labels that form the base domain (used to split custom_fqdn into host and zone). Defaults to 2, which covers the common case (e.g., 'faithtechinc.com'). Increase to 3 for three-part TLDs or delegated zones (e.g., 'app.faithtechinc.com' as the zone → set to 3)."
  type        = number
  default     = 2
}

variable "redirect_uris" {
  description = "Additional redirect URIs to include in the Azure AD application registration (e.g., localhost dev URIs like 'https://localhost:7142/signin-oidc'). Some URIs are added automatically: the default app service hostname with /.auth/login/aad/callback and /signin-oidc, and (when custom_fqdn is set) the custom hostname with both /.auth/login/aad/callback and /signin-oidc."
  type        = list(string)
  default     = []
}

variable "api_permissions" {
  description = <<-EOT
    List of API permissions to grant the Azure AD application. Permissions with the same
    resource_app_id are grouped automatically.

    Attributes:
      id              - Permission GUID. Find via Azure CLI:
                          Delegated : az ad sp show --id <resource_app_id> --query "oauth2PermissionScopes[?value=='<scope_name>']"
                          Application: az ad sp show --id <resource_app_id> --query "appRoles[?value=='<role_name>']"
      type            - "Scope" for Delegated permissions, "Role" for Application permissions.
      resource_app_id - (Optional) App ID of the target API.
                        Defaults to Microsoft Graph (00000003-0000-0000-c000-000000000000).

    Common Microsoft Graph permission IDs:
      37f7f235-527c-4136-accd-4a02d197296e = openid    | "Sign users in"              | Delegated
      14dad69e-099b-42c9-810b-d002981feec1 = profile   | "View users' basic profile"  | Delegated
      e1fe6dd8-ba31-4d61-89e7-88639da4683d = User.Read | "Read user profile"          | Delegated
  EOT
  type = list(object({
    id              = string
    type            = string
    resource_app_id = optional(string)
  }))
  default = []
}

variable "implicit_grant_access_token_issuance_enabled" {
  description = "Whether the Azure AD application issues access tokens via the implicit grant flow. Defaults to false — Easy Auth uses PKCE/auth-code flow, which does not require implicit grant. Only enable if your application explicitly requires it (e.g., legacy SPA flows)."
  type        = bool
  default     = false
}

variable "implicit_grant_id_token_issuance_enabled" {
  description = "Whether the Azure AD application issues ID tokens via the implicit grant flow. Defaults to false — Easy Auth uses PKCE/auth-code flow, which does not require implicit grant. Only enable if your application explicitly requires it (e.g., legacy SPA flows)."
  type        = bool
  default     = false
}


variable "app_settings" {
  description = "Additional or override app settings (environment variables) for the App Service. Merged with module defaults; caller-supplied values take precedence. Module defaults: WEBSITES_ENABLE_APP_SERVICE_STORAGE, ASPNETCORE_ENVIRONMENT, KeyVaultName, ENV, ASPNETCORE_FORWARDEDHEADERS_ENABLED."
  type        = map(string)
  default     = {}
}

variable "auth_settings_v2" {
  # Enables Azure AD Easy Auth on the App Service. Null (default) disables it.
  # Setting this to {} (empty object) enables auth with all defaults:
  #   - Uses the module-created Azure AD app registration
  #   - Creates a client secret, stores it in Key Vault, and wires it up as an app setting
  #   - Enables token store, sets logout endpoint, and configures forward proxy for internal apps
  # See module-docs for full attribute reference and example.
  description = <<-EOT
    Optional Azure AD Easy Auth. Setting to {} (or any object) enables auth with sensible defaults:
    the module-created app registration is used automatically, a client secret is created and stored
    in Key Vault, token store is enabled, and the proxy convention is set for internal apps.
    Set active_directory_v2.client_id only if you need a different (externally managed) app registration.
    See module-docs.
  EOT
  type = object({
    manage_client_secret     = optional(bool)           # default: true when using module app, false when client_id is explicit
    aad_allowed_tenants      = optional(string)         # defaults to current tenant_id
    require_authentication   = optional(bool, true)
    unauthenticated_action   = optional(string, "RedirectToLoginPage")
    logout_endpoint          = optional(string, "/.auth/logout")
    forward_proxy_convention = optional(string, "Standard") # Standard = trust X-Forwarded-* headers (correct for internal apps behind LBs)
    token_store_enabled      = optional(bool, true)
    active_directory_v2 = optional(object({
      client_id                  = optional(string)     # defaults to the module-created app registration
      tenant_auth_endpoint       = optional(string)     # defaults to current tenant
      client_secret_setting_name = optional(string, "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET")
      allowed_audiences          = optional(list(string), []) # api://<client-id> is always added automatically
    }), {})
  })
  default = null
}

variable "sticky_app_setting_names" {
  # Typically includes MICROSOFT_PROVIDER_AUTHENTICATION_SECRET when using Easy Auth.
  # See module-docs.
  description = "App setting names to mark as deployment-slot sticky."
  type        = list(string)
  default     = []
}

variable "site_config" {
  description = "Overrides for the App Service site_config block. Any non-null value replaces the module default. Module default: vnet_route_all_enabled = true."
  type = object({
    always_on                                     = optional(bool)
    container_registry_managed_identity_client_id = optional(string)
    container_registry_use_managed_identity       = optional(bool)
    ftps_state                                    = optional(string)
    health_check_path                             = optional(string)
    health_check_eviction_time_in_min             = optional(number)
    http2_enabled                                 = optional(bool)
    minimum_tls_version                           = optional(string)
    remote_debugging_enabled                      = optional(bool)
    remote_debugging_version                      = optional(string)
    scm_minimum_tls_version                       = optional(string)
    scm_use_main_ip_restriction                   = optional(bool)
    use_32_bit_worker                             = optional(bool)
    vnet_route_all_enabled                        = optional(bool)
    websockets_enabled                            = optional(bool)
    worker_count                                  = optional(number)
  })
  default = {}
}

variable "application_stack" {
  description = "Overrides for the application_stack block within site_config. docker_registry_url, docker_registry_username, and docker_registry_password default to the module-managed ACR when not provided."
  type = object({
    docker_image_name        = optional(string)
    docker_registry_url      = optional(string)
    docker_registry_username = optional(string)
    docker_registry_password = optional(string)
  })
  default = {}
}

## Local Values
locals {
  # Mapping tables
  env_medium_map = {
    p   = "prod"
    d   = "dev"
    s   = "stage"
    t   = "test"
    uat = "uat"
    np  = "nonprod"
    q   = "qa"
  }

  env_long_map = {
    p   = "Production"
    d   = "Development"
    s   = "Stage"
    t   = "Test"
    uat = "UAT"
    np  = "Non-Production"
    q   = "QA"
  }

  # Lookups
  env_med   = lookup(local.env_medium_map, var.environment, var.environment)
  env_long  = lookup(local.env_long_map, var.environment, var.environment)
  env_short = var.environment

  # Shared cleaned name parts for Azure resources with strict naming constraints.
  # _az_name_alnum_*  — all non-alphanumeric characters removed (for ACR, Storage Account, etc.)
  # _az_name_base_nh  — base_name with only hyphens removed (for Key Vault style: hyphens allowed
  #                     in the fixed parts but not accepted from base_name input)
  _az_name_alnum_site = replace(var.site, "/[^a-zA-Z0-9]/", "")
  _az_name_alnum_base = replace(var.base_name, "/[^a-zA-Z0-9]/", "")
  _az_name_alnum_env  = replace(local.env_short, "/[^a-zA-Z0-9]/", "")
  _az_name_base_nh    = replace(var.base_name, "-", "")

  # Resource names — 24-char max; only the base_name portion is truncated.
  # Fixed overhead is inlined so no extra intermediate locals are needed.
  # ACR:     {site}{base}acr{env}        — no separators; fixed = site + 3("acr") + env
  # SA:      {site}{base}{env}           — no separators; fixed = site + env
  # KV:      {site}-{base}-kv-{env}      — hyphens in fixed parts; fixed = site + 5("-" + "-kv-") + env
  acr_name    = "${local._az_name_alnum_site}${substr(local._az_name_alnum_base, 0, max(0, 24 - length(local._az_name_alnum_site) - 3 - length(local._az_name_alnum_env)))}acr${local._az_name_alnum_env}"
  sa_name     = "${local._az_name_alnum_site}${substr(local._az_name_alnum_base, 0, max(0, 24 - length(local._az_name_alnum_site) - length(local._az_name_alnum_env)))}${local._az_name_alnum_env}"
  kv_name     = "${var.site}-${substr(local._az_name_base_nh, 0, max(0, 24 - length(var.site) - 5 - length(local.env_short)))}-kv-${local.env_short}"
  _sa_pe_base = "${var.site}-${local._az_name_base_nh}-sa-${local.env_short}"

  # Custom domain — split var.custom_fqdn into host and base-domain parts.
  # A trailing period is stripped first (some DNS tooling appends one).
  # base_domain is the last N labels where N = var.base_domain_labels (default 2);
  # host_name is everything before them.
  #
  # Examples (base_domain_labels = 2, the default):
  #   "prophix.faithtechinc.com"       → host = "prophix",    base = "faithtechinc.com"
  #   "myhost.app.domain.com"          → host = "myhost.app", base = "domain.com"
  #   "myhost.app.domain.com."         → host = "myhost.app", base = "domain.com"  (trailing period stripped)
  #
  # Examples (base_domain_labels = 3):
  #   "myhost.app.faithtechinc.com"    → host = "myhost",     base = "app.faithtechinc.com"
  _custom_fqdn_normalized = trimsuffix(var.custom_fqdn != null ? var.custom_fqdn : "", ".")
  _custom_fqdn_parts      = local._custom_fqdn_normalized != "" ? split(".", local._custom_fqdn_normalized) : []
  custom_base_domain      = local._custom_fqdn_normalized != "" ? join(".", slice(local._custom_fqdn_parts, length(local._custom_fqdn_parts) - var.base_domain_labels, length(local._custom_fqdn_parts))) : ""
  custom_host_name        = local._custom_fqdn_normalized != "" ? join(".", slice(local._custom_fqdn_parts, 0, length(local._custom_fqdn_parts) - var.base_domain_labels)) : ""
  deploy_custom_domain    = local._custom_fqdn_normalized != ""

  # Computed App Service name and default hostname.
  # Using computed locals rather than azurerm_linux_web_app.this.default_hostname prevents a
  # dependency cycle when auth is enabled: app registration needs the hostname for redirect URIs,
  # and the web app needs the app registration for auth settings. The hostname is always
  # <name>.azurewebsites.net — there is no runtime difference between this and the resource attribute.
  _web_app_name             = "${var.site}-${var.base_name}-app-${local.env_short}"
  _web_app_default_hostname = "${local._web_app_name}.azurewebsites.net"

  # Microsoft Graph App ID — used as the default resource_app_id for api_permissions entries
  # that do not specify a resource_app_id.
  _microsoft_graph_app_id = "00000003-0000-0000-c000-000000000000"

  # Group api_permissions by resource_app_id so that one required_resource_access block is
  # emitted per API (as required by the azuread provider). Entries without a resource_app_id
  # default to Microsoft Graph.
  api_permissions_grouped = {
    for perm in var.api_permissions :
    coalesce(perm.resource_app_id, local._microsoft_graph_app_id) => perm...
  }

  # Auth v2 helpers
  _auth_enabled = var.auth_settings_v2 != null

  # True when the caller did NOT supply an explicit client_id — module-created app registration is used.
  _auth_uses_module_app = local._auth_enabled && try(var.auth_settings_v2.active_directory_v2.client_id, null) == null

  # Whether to create the client secret and store it in Key Vault.
  # Defaults to true when using the module app, false when an external app is specified.
  # Can be overridden explicitly via auth_settings_v2.manage_client_secret.
  _manage_auth_secret = local._auth_enabled && coalesce(
    try(var.auth_settings_v2.manage_client_secret, null),
    local._auth_uses_module_app
  )

  # The app setting name used to pass the client secret to Easy Auth.
  _auth_secret_setting_name = local._auth_enabled ? coalesce(
    try(var.auth_settings_v2.active_directory_v2.client_secret_setting_name, null),
    "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
  ) : "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
}
