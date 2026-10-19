<!-- MODULE_METADATA
name: t-linux_app_service_internal
type: terraform
description: Azure App Service for Internal Web Applications
current_version: 1.2.21
last_updated: 2026-07-02T13:51:23.354746
-->

# linux_app_service_internal Module

This is a module for creating a Linux Azure App Service for internal web applications.

See [module-docs](module-docs.md) for more info

## Multi-Environment Deployment Pattern

This module is designed to be consumed from a caller repo that uses `.tfvars` files to deploy the same Terraform code across multiple environments. The environment-specific values (network names, SKU, custom domain, etc.) live in `p.tfvars`, `d.tfvars`, etc., while `main.tf` and `variables.tf` stay unchanged between runs.

```
terraform plan  -var-file="p.tfvars"   # production
terraform plan  -var-file="d.tfvars"   # development
```

### Example caller layout

```
terraform/
  main.tf        # module invocation — never changes between environments
  variables.tf   # declares all variables passed via tfvars
  p.tfvars       # production values
  d.tfvars       # development values
```

---

### `main.tf`

```hcl
data "azurerm_client_config" "current" {}

module "myapp" {
  source = "./modules/linux_app_service_internal"
  providers = {
    azurerm                  = azurerm
    azurerm.ftdc4-production = azurerm.FTDC4-Production
  }

  # Site and Environment
  site                = var.site
  environment         = var.environment
  resource_group_name = "${lower(var.site)}-${lower(var.base_name)}-${var.environment}"
  base_name           = var.base_name

  # Custom Domain (optional — omit or set to "" to skip)
  custom_fqdn = var.custom_fqdn

  # Azure AD redirect URIs added on top of the auto-generated defaults
  # Auto-generated: /.auth/login/aad/callback and /signin-oidc for both default and custom hostnames
  redirect_uris = var.redirect_uris

  # Azure AD API permissions (additive — omit to register no extra permissions)
  api_permissions = [
    # 37f7f235-527c-4136-accd-4a02d197296e = openid   | Delegated | "Sign users in"
    { id = "37f7f235-527c-4136-accd-4a02d197296e", type = "Scope" },
    # 14dad69e-099b-42c9-810b-d002981feec1 = profile  | Delegated | "View users' basic profile"
    { id = "14dad69e-099b-42c9-810b-d002981feec1", type = "Scope" },
  ]

  # Network
  virtual_network_name                = var.virtual_network_name
  virtual_network_resource_group_name = var.virtual_network_resource_group_name
  private_link_subnet_name            = var.private_link_subnet_name
  vnet_integration_subnet_name        = var.vnet_integration_subnet_name

  # App Service
  app_service_sku = var.app_service_sku

  # Easy Auth (optional — omit entirely if not needed)
  # auth_settings_v2          = var.auth_settings_v2
  # sticky_app_setting_names  = var.sticky_app_setting_names

  tags = {
    Environment      = local.env_long
    CreatedBy        = "INF Terraform"
    Asset            = var.base_name
    OperationalOwner = "DAG"
    MaintainedBy     = "BT Systems"
  }
}
```

---

### `variables.tf`

```hcl
variable "site" {
  description = "Site / data center identifier (e.g., 'ftdc4')"
  validation {
    condition     = can(regex("^[a-z0-9]+$", var.site))
    error_message = "Lowercase letters and numbers only."
  }
}

variable "environment" {
  description = "Environment short code (p = prod, d = dev, s = stage, etc.)"
  validation {
    condition     = can(regex("^(p|d|s|t|uat|np|q)$", var.environment))
    error_message = "Must be one of: p, d, s, t, uat, np, q."
  }
}

variable "base_name" {
  description = "Base name for all resources (e.g., 'myapp')"
}

variable "virtual_network_name" {
  description = "Name of the Virtual Network"
}

variable "virtual_network_resource_group_name" {
  description = "Resource group containing the Virtual Network"
}

variable "private_link_subnet_name" {
  description = "Subnet name for Private Link endpoints"
}

variable "vnet_integration_subnet_name" {
  description = "Subnet name for VNet Integration"
  default     = "appservice-shared-vnet-integration"
}

variable "app_service_sku" {
  description = "App Service Plan SKU (production requires a premium SKU, e.g., P0v4)"
}

variable "custom_fqdn" {
  description = "Full custom domain FQDN to bind (e.g., 'myapp.faithtechinc.com'). Leave empty to skip custom domain."
  default     = ""
}

variable "redirect_uris" {
  description = "Additional Azure AD redirect URIs beyond the auto-generated defaults (e.g., localhost dev URIs)"
  type        = list(string)
  default     = []
}

# Advanced overrides — only declare and set these if your application requires them.
# See the Advanced Overrides section below and module-docs.md for full details.

variable "app_settings" {
  description = "Additional or override app settings. Merged on top of module defaults."
  type        = map(string)
  default     = {}
}

variable "site_config" {
  description = "Optional overrides for the site_config block."
  type        = any
  default     = {}
}

variable "application_stack" {
  description = "Optional overrides for the application_stack block (e.g., external registry)."
  type        = any
  default     = {}
}

locals {
  env_long_map = {
    p   = "Production"
    d   = "Development"
    s   = "Stage"
    t   = "Test"
    uat = "UAT"
    np  = "Non-Production"
    q   = "QA"
  }
  env_long = lookup(local.env_long_map, var.environment, var.environment)
}
```

---

### `p.tfvars` (production)

```hcl
site                                = "ftdc4"
environment                         = "p"
base_name                           = "myapp"
virtual_network_name                = "FTDC4-Production1-P"
virtual_network_resource_group_name = "FTDC4-Network-P"
private_link_subnet_name            = "Application"
vnet_integration_subnet_name        = "appservice-shared-vnet-integration"
app_service_sku                     = "P0v4"
custom_fqdn                         = "myapp.faithtechinc.com"
redirect_uris                       = ["https://localhost:7142/signin-oidc"]
```

### `d.tfvars` (development)

```hcl
site                                = "ftdc4"
environment                         = "d"
base_name                           = "myapp"
virtual_network_name                = "FTDC4-Development1-D"
virtual_network_resource_group_name = "FTDC4-Network-D"
private_link_subnet_name            = "Dev-Application"
vnet_integration_subnet_name        = "appservice-shared-vnet-integration"
app_service_sku                     = "P0v4"
custom_fqdn                         = ""
redirect_uris                       = ["https://localhost:7142/signin-oidc"]
```

> **Note:** `custom_fqdn` is left empty for dev here — no custom DNS binding or certificate will be created, and the custom-domain redirect URIs will be omitted from the Azure AD App Registration automatically.

---

## Advanced Overrides

> **Only use these variables when your application specifically requires it.** The module defaults cover the standard deployment pattern. These are escape hatches for edge cases.

Pass them in the module call alongside your normal inputs. You only need to declare them in your caller's `variables.tf` if you want them to vary per environment via tfvars.

```hcl
module "myapp" {
  source = "./modules/linux_app_service_internal"
  # ... required variables ...

  # Inject additional env vars, or override a module default.
  # Merged on top of module defaults; your keys win on collision.
  app_settings = {
    "MY_API_BASE_URL"   = "https://api.internal.example.com"
    "FEATURE_X_ENABLED" = "true"
    # Example override of a module default:
    # "ASPNETCORE_ENVIRONMENT" = "Staging"
  }

  # Override specific site_config properties.
  # Omit any attribute you don't need to change.
  site_config = {
    always_on         = true
    health_check_path = "/health"
    worker_count      = 2
  }

  # Override the container registry only if NOT using the module-provisioned ACR.
  # If you set any credential attribute, set all three together.
  application_stack = {
    docker_registry_url      = "https://mysharedregistry.azurecr.io"
    docker_registry_username = var.shared_acr_username
    docker_registry_password = var.shared_acr_password
  }
}
```

See [module-docs](module-docs.md#advanced-configuration-overrides) for the full list of supported `site_config` attributes.

---

## Easy Auth (Azure AD Authentication)

Enable built-in Azure AD authentication with a single block. The minimum viable configuration is:

```hcl
auth_settings_v2 = {}
```

That single line:
- Uses the module-created Azure AD app registration automatically
- Creates a client secret and stores it in the Key Vault as `auth-client-secret`
- Wires `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` as a Key Vault reference app setting
- Enables the token store (required for refresh token support)
- Sets `/.auth/logout` as the logout endpoint
- Configures `forward_proxy_convention = "Standard"` (correct for internal apps behind load balancers)
- Auto-adds `api://<client-id>` to `allowed_audiences`

See [module-docs](module-docs.md#easy-auth) for the full attribute reference and advanced examples.

### Client secret rotation

The secret has no expiry. To rotate it:

```bash
terraform taint 'module.<name>.azuread_application_password.auth_secret[0]'
terraform apply
```

This replaces the secret in Azure AD, updates the Key Vault secret, and the App Service picks it up automatically via the KV reference.
