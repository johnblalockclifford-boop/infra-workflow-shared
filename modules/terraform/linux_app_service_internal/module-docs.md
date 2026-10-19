# Linux App Service Internal Module

This Terraform module creates a fully configured Linux App Service environment with private networking, including:

- Azure Container Registry (ACR)
- Azure Key Vault with private endpoint
- Azure Storage Account with private endpoint
- Azure App Service Plan (Linux)
- Azure Linux Web App with VNet integration and private endpoint
- Optional custom domain with managed certificate
- Azure AD Application for SSO

## Features

- **Private Networking**: All resources are secured with private endpoints and VNet integration
- **Container Support**: Includes ACR for container image hosting
- **Secure Configuration**: Key Vault for secrets management with RBAC authorization
- **Custom Domain Support**: Optional custom domain configuration with automatic certificate management
- **Identity Management**: System-assigned managed identity for the App Service
- **Environment Flexibility**: Supports multiple environments (dev, test, stage, prod)
- **HTTPS Only**: The App Service enforces HTTPS (`https_only = true`), redirecting all HTTP traffic to HTTPS

## Breaking Changes

### v1.2.19 — Auth v2 improvements

#### `implicit_grant_*` defaults changed to `false`

`implicit_grant_access_token_issuance_enabled` and `implicit_grant_id_token_issuance_enabled` both previously defaulted to `true`. They now default to `false`, matching the current Azure Portal default for new app registrations. Easy Auth uses PKCE/auth-code flow and does not require implicit grant.

**Impact:** Existing app registrations managed by this module will have implicit grant disabled on the next `terraform apply`. If your application explicitly depends on implicit grant tokens (e.g., a legacy SPA), set either variable to `true` in your caller.

#### `auth_settings_v2.active_directory_v2.client_id` is now optional

Previously required, it now defaults to the module-created app registration's `client_id`. Existing callers that were passing the output back in can remove that attribute.

#### New resources created when `auth_settings_v2` is set (with module app)

When `auth_settings_v2` is set and no explicit `client_id` is supplied (the new default), three additional resources are created:
- `azuread_application_password.auth_secret[0]` — client secret
- `azurerm_key_vault_secret.auth_client_secret[0]` — stores the secret in Key Vault
- `azurerm_role_assignment.runner_keyvault_secrets_officer[0]` — grants the Terraform runner write access to Key Vault secrets

Existing deployments that already had `auth_settings_v2` set with an explicit `client_id` are unaffected.

---

### `custom_faithtechinc_hostname` → `custom_fqdn`

The `custom_faithtechinc_hostname` variable (which accepted only the host portion, e.g., `"myapp"`) has been **replaced** by `custom_fqdn`, which accepts the full FQDN (e.g., `"myapp.faithtechinc.com"`).

```hcl
# Before
custom_faithtechinc_hostname = "myapp"

# After
custom_fqdn = "myapp.faithtechinc.com"
```

The module now derives the DNS zone name from the FQDN automatically, so it supports any public DNS zone — not just `faithtechinc.com`. Set `base_domain_labels = 3` if your zone itself has three labels (e.g., `app.faithtechinc.com`).

## Requirements

| Name | Version |
|------|---------|
| terraform | n/a |
| azurerm | ~> 4.0 |
| azuread | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.0 |
| azuread | ~> 2.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_container_registry.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_role_assignment.appservice_keyvault_secrets_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.appservice_keyvault_cert_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.runner_keyvault_cert_officer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.appservice_mssp_keyvault_secerts](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.appservice_mssp_keyvault_cert](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_private_endpoint.keyvault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_storage_account.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_private_endpoint.storageaccount](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_service_plan.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |
| [azurerm_linux_web_app.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app) | resource |
| [azurerm_private_endpoint.appservice](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_dns_cname_record.custom_hostname](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_cname_record) | resource |
| [azurerm_app_service_custom_hostname_binding.custom_hostname](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_custom_hostname_binding) | resource |
| [azurerm_dns_txt_record.cert_validation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_txt_record) | resource |
| [azurerm_app_service_managed_certificate.custom_cert](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_managed_certificate) | resource |
| [azurerm_app_service_certificate_binding.custom_cert_binding](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_certificate_binding) | resource |
| [azuread_application.app](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_service_principal.sp](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azuread_application_password.auth_secret](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource (conditional — when auth_settings_v2 is set with module app) |
| [azurerm_key_vault_secret.auth_client_secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource (conditional — when auth_settings_v2 is set with module app) |
| [azurerm_role_assignment.runner_keyvault_secrets_officer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource (conditional — when auth_settings_v2 is set with module app) |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_private_dns_zone.azurewebsites](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |
| [azurerm_private_dns_zone.storageaccountblob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |
| [azurerm_private_dns_zone.keyvault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |
| [azurerm_dns_zone.faithtechinc_com](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/dns_zone) | data source |
| [azurerm_dns_zone.faith1_net](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/dns_zone) | data source |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |
| [azurerm_subnet.private_link_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_subnet.vnet_integration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azuread_service_principal.microsoft_web_app](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_site"></a> [site](#input\_site) | Site a.k.a. Data Center | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment (short, eg., `p` for prod, `d` for dev) | `string` | n/a | yes |
| <a name="input_base_name"></a> [base\_name](#input\_base\_name) | Base name for resources (e.g., 'myapp') | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group where the app service resources will be created | `string` | n/a | yes |
| <a name="input_virtual_network_name"></a> [virtual\_network\_name](#input\_virtual\_network\_name) | Name of the Virtual Network | `string` | n/a | yes |
| <a name="input_virtual_network_resource_group_name"></a> [virtual\_network\_resource\_group\_name](#input\_virtual\_network\_resource\_group\_name) | Resource Group name of the Virtual Network | `string` | n/a | yes |
| <a name="input_private_link_subnet_name"></a> [private\_link\_subnet\_name](#input\_private\_link\_subnet\_name) | Name of the Subnet for Private Link endpoints | `string` | n/a | yes |
| <a name="input_vnet_integration_subnet_name"></a> [vnet\_integration\_subnet\_name](#input\_vnet\_integration\_subnet\_name) | Name of the Subnet for VNet Integration | `string` | `"appservice-shared-vnet-integration"` | no |
| <a name="input_app_service_sku"></a> [app\_service\_sku](#input\_app\_service\_sku) | App Service Plan SKU - Production requires a premium sku | `string` | `"P0v4"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to resources | `map(string)` | n/a | yes |
| <a name="input_custom_fqdn"></a> [custom\_fqdn](#input\_custom\_fqdn) | **Breaking change** (renamed from `custom_faithtechinc_hostname`). Full FQDN for the custom hostname (e.g., `"myapp.faithtechinc.com"`). Leave empty to skip custom domain configuration. The host and zone are split automatically. | `string` | `""` | no |
| <a name="input_base_domain_labels"></a> [base\_domain\_labels](#input\_base\_domain\_labels) | Number of DNS labels forming the base domain zone when splitting `custom_fqdn`. Default `2` covers most cases (e.g., `faithtechinc.com`). Set to `3` for three-label zones (e.g., `app.faithtechinc.com`). | `number` | `2` | no |
| <a name="input_redirect_uris"></a> [redirect\_uris](#input\_redirect\_uris) | Additional redirect URIs to register on the Azure AD application (e.g., `"https://localhost:7142/signin-oidc"`). Several URIs are added automatically — see the **Azure AD Application** section below. | `list(string)` | `[]` | no |
| <a name="input_api_permissions"></a> [api\_permissions](#input\_api\_permissions) | API permissions to grant the Azure AD application. Each object has `id` (permission GUID), `type` (`"Scope"` for Delegated or `"Role"` for Application), and optional `resource_app_id` (omit to default to Microsoft Graph). Permissions targeting the same API are grouped automatically. See the **Azure AD Application** section below. | `list(object({ id = string, type = string, resource_app_id = optional(string) }))` | `[]` | no |
| <a name="input_implicit_grant_access_token_issuance_enabled"></a> [implicit\_grant\_access\_token\_issuance\_enabled](#input\_implicit\_grant\_access\_token\_issuance\_enabled) | Whether the Azure AD application issues access tokens via the implicit grant flow. Defaults to `false` — Easy Auth uses PKCE/auth-code flow. | `bool` | `false` | no |
| <a name="input_implicit_grant_id_token_issuance_enabled"></a> [implicit\_grant\_id\_token\_issuance\_enabled](#input\_implicit\_grant\_id\_token\_issuance\_enabled) | Whether the Azure AD application issues ID tokens via the implicit grant flow. Defaults to `false` — Easy Auth uses PKCE/auth-code flow. | `bool` | `false` | no |
| <a name="input_app_settings"></a> [app\_settings](#input\_app\_settings) | Additional or override app settings (environment variables). Merged on top of module defaults; caller-supplied keys take precedence. **Only set this if your application requires settings beyond or different from the defaults.** See the **Environment Variables** note for the full list of defaults. | `map(string)` | `{}` | no |
| <a name="input_site_config"></a> [site\_config](#input\_site\_config) | Optional overrides for the App Service `site_config` block. Only attributes you supply are applied; omitted attributes use provider defaults. Module default: `vnet_route_all_enabled = true`. **Only set this if you need non-default site configuration.** See the **Advanced Configuration Overrides** section for supported attributes and examples. | `object({...})` | `{}` | no |
| <a name="input_application_stack"></a> [application\_stack](#input\_application\_stack) | Optional overrides for the `application_stack` block. `docker_registry_url`, `docker_registry_username`, and `docker_registry_password` default to the module-managed ACR when not set. **Only set this if you need to point to a registry other than the module-provisioned ACR.** | `object({...})` | `{}` | no |
| <a name="input_auth_settings_v2"></a> [auth\_settings\_v2](#input\_auth\_settings\_v2) | Optional Azure AD Easy Auth. `null` (default) disables it. Setting to `{}` enables auth with all defaults: module app used, client secret created and stored in Key Vault, token store enabled. Set `active_directory_v2.client_id` only to use an external app registration. See the **Easy Auth** section below. | `object({...})` | `null` | no |
| <a name="input_sticky_app_setting_names"></a> [sticky\_app\_setting\_names](#input\_sticky\_app\_setting\_names) | App setting names to mark as deployment-slot sticky. Typically includes `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` when using Easy Auth. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_service_name"></a> [app\_service\_name](#output\_app\_service\_name) | Name of the Linux App Service |
| <a name="output_app_service_id"></a> [app\_service\_id](#output\_app\_service\_id) | Resource ID of the Linux App Service |
| <a name="output_app_service_default_hostname"></a> [app\_service\_default\_hostname](#output\_app\_service\_default\_hostname) | Default hostname of the App Service |
| <a name="output_app_service_principal_id"></a> [app\_service\_principal\_id](#output\_app\_service\_principal\_id) | Principal ID of the App Service managed identity |
| <a name="output_container_registry_login_server"></a> [container\_registry\_login\_server](#output\_container\_registry\_login\_server) | Login server URL of the Container Registry |
| <a name="output_container_registry_admin_username"></a> [container\_registry\_admin\_username](#output\_container\_registry\_admin\_username) | Admin username for the Container Registry |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | Resource ID of the Key Vault |
| <a name="output_key_vault_uri"></a> [key\_vault\_uri](#output\_key\_vault\_uri) | URI of the Key Vault |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the Storage Account |
| <a name="output_storage_account_primary_blob_endpoint"></a> [storage\_account\_primary\_blob\_endpoint](#output\_storage\_account\_primary\_blob\_endpoint) | Primary blob endpoint of the Storage Account |
| <a name="output_custom_domain_url"></a> [custom\_domain\_url](#output\_custom\_domain\_url) | Full URL of the custom domain (if configured) |
| <a name="output_auth_client_secret_kv_secret_name"></a> [auth\_client\_secret\_kv\_secret\_name](#output\_auth\_client\_secret\_kv\_secret\_name) | Name of the Key Vault secret holding the Easy Auth client secret (`auth-client-secret`). Null when auth is disabled or `manage_client_secret = false`. |
| <a name="output_auth_client_secret_kv_secret_id"></a> [auth\_client\_secret\_kv\_secret\_id](#output\_auth\_client\_secret\_kv\_secret\_id) | Versionless Key Vault secret URI for the Easy Auth client secret. Null when auth is disabled or `manage_client_secret = false`. |

## Example Usage

### Basic Usage

```hcl
module "linux_app_service" {
  source = "git::https://github.com/Faith-Technologies/infra-workflow-shared.git//modules/terraform/linux_app_service_internal"

  # Site and Environment
  site        = "ftdc4"
  environment = "d"
  base_name   = "myapp"
  resource_group_name = "ftdc4-myapp-d"

  # Network Configuration
  virtual_network_name                = "ftdc4-network-vnet-d"
  virtual_network_resource_group_name = "ftdc4-network-d"
  private_link_subnet_name            = "private-endpoints"
  vnet_integration_subnet_name        = "appservice-shared-vnet-integration"

  # App Service Configuration
  app_service_sku = "P0v4"

  # Tags
  tags = {
    Environment      = "Development"
    ManagedBy        = "Terraform"
    Application      = "MyApp"
    CostCenter       = "IT"
  }
}
```

### Production with Custom Domain

```hcl
module "linux_app_service_prod" {
  source = "git::https://github.com/Faith-Technologies/infra-workflow-shared.git//modules/terraform/linux_app_service_internal"

  # Site and Environment
  site        = "ftdc4"
  environment = "p"
  base_name   = "myapp"
  resource_group_name = "ftdc4-myapp-p"

  # Network Configuration
  virtual_network_name                = "ftdc4-network-vnet-p"
  virtual_network_resource_group_name = "ftdc4-network-p"
  private_link_subnet_name            = "private-endpoints"
  vnet_integration_subnet_name        = "appservice-shared-vnet-integration"

  # App Service Configuration
  app_service_sku = "P1v3"  # Production SKU

  # Custom Domain
  custom_fqdn = "myapp.faithtechinc.com"

  # Azure AD Application
  # Localhost dev URIs — automatically added URIs are listed in the Azure AD Application section of Notes
  redirect_uris = ["https://localhost:7142/signin-oidc"]

  api_permissions = [
    # 37f7f235-527c-4136-accd-4a02d197296e = openid  | "Sign users in"             | Delegated
    { id = "37f7f235-527c-4136-accd-4a02d197296e", type = "Scope" },
    # 14dad69e-099b-42c9-810b-d002981feec1 = profile | "View users' basic profile" | Delegated
    { id = "14dad69e-099b-42c9-810b-d002981feec1", type = "Scope" },
  ]

  # Tags
  tags = {
    Environment      = "Production"
    ManagedBy        = "Terraform"
    Application      = "MyApp"
    CostCenter       = "IT"
    BusinessOwner    = "Engineering"
  }
}

# Access the outputs
output "app_url" {
  value = module.linux_app_service_prod.app_service_default_hostname
}

output "container_registry" {
  value = module.linux_app_service_prod.container_registry_login_server
}

output "key_vault" {
  value = module.linux_app_service_prod.key_vault_uri
}
```

## Notes

- **Resource Group**: The target resource group must already exist, and its name must be provided through `resource_group_name`
- **Private DNS Zones**: The module requires private DNS zones for azurewebsites.net, blob.core.windows.net, and vaultcore.azure.net in the FTDC4-Network-P resource group
- **Public DNS Zones**: For custom domains, the DNS zone matching `custom_fqdn`'s base domain (e.g., `faithtechinc.com`) must exist in the `FTDC4-PublicDNS-P` resource group. Use `base_domain_labels` to control how many trailing labels form the zone name
- **Subnets**: Requires pre-configured subnets for private endpoints and VNet integration
- **Docker Images**: The App Service is configured with a placeholder Docker image that should be updated through CI/CD pipelines
- **RBAC**: The module sets up appropriate RBAC roles for the App Service to access Key Vault secrets and certificates
- **Environment Variables**: The following app settings are set by default on every App Service deployed by this module:

  | Setting | Value | Purpose |
  |---------|-------|---------|
  | `WEBSITES_ENABLE_APP_SERVICE_STORAGE` | `false` | Disables the default shared storage mount (not needed for container workloads) |
  | `ASPNETCORE_ENVIRONMENT` | Environment long name (e.g., `Production`) | Selects the ASP.NET Core environment configuration profile |
  | `KeyVaultName` | Name of the provisioned Key Vault | Allows the application to resolve the Key Vault by name at startup |
  | `ENV` | Title-cased medium name (e.g., `Prod`) | Short environment label for application-level use |
  | `ASPNETCORE_FORWARDEDHEADERS_ENABLED` | `true` | Ensures ASP.NET Core reads `X-Forwarded-*` headers correctly when running behind a reverse proxy |

  These settings are always present and do not need to be re-declared in the calling module. Use `app_settings` to inject additional settings or override a default value.

## Advanced Configuration Overrides

> **These variables are optional escape hatches. Do not use them unless your application specifically requires it** — the module defaults are correct for the vast majority of deployments.

### `app_settings`

Merged on top of the module defaults. Use this to add application-specific environment variables or override a default setting. Keys you supply win on collision.

```hcl
app_settings = {
  # Add application-specific settings
  "MY_API_BASE_URL"     = "https://api.internal.example.com"
  "FEATURE_X_ENABLED"  = "true"

  # Override a module default (e.g., force a specific environment label)
  "ASPNETCORE_ENVIRONMENT" = "Staging"
}
```

### `site_config`

Overrides specific properties of the `site_config` block. Only the attributes you supply are applied; everything else is left at provider defaults (except `vnet_route_all_enabled`, which defaults to `true`). Supported attributes mirror the `site_config` block of the `azurerm_linux_web_app` resource.

```hcl
site_config = {
  always_on                = true
  health_check_path        = "/health"
  health_check_eviction_time_in_min = 10
  minimum_tls_version      = "1.3"
  worker_count             = 2
}
```

### `application_stack`

The module automatically connects the App Service to the ACR it provisions. Override this only when you need to point to a **different registry** (e.g., a shared organization registry). If you set any credential attribute, set all three together.

```hcl
application_stack = {
  docker_registry_url      = "https://mysharedregistry.azurecr.io"
  docker_registry_username = var.shared_acr_username
  docker_registry_password = var.shared_acr_password
}
```

## Easy Auth

> **Only use this if your application requires Azure AD Easy Auth (built-in authentication at the platform layer).** Most applications handle authentication in their own code and do not need this.

Setting `auth_settings_v2` enables Azure AD authentication on the App Service. The module mirrors what the Azure Portal does in a single click — including creating the client secret, storing it in Key Vault, and wiring it up automatically.

### What happens automatically when `auth_settings_v2` is set

| Action | Detail |
|--------|--------|
| App registration used | Module-created app (`azuread_application.app`) unless `client_id` is supplied |
| Client secret created | `azuread_application_password.auth_secret` (no expiry; rotate via `taint`) |
| Secret stored in Key Vault | `azurerm_key_vault_secret.auth_client_secret` (`auth-client-secret`) |
| App setting wired up | `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET = @Microsoft.KeyVault(SecretUri=...)` |
| Allowed tenants | `WEBSITE_AUTH_AAD_ALLOWED_TENANTS` set to current tenant (configurable) |
| Token store | Enabled (`token_store_enabled = true`) |
| Logout endpoint | `/.auth/logout` |
| Forward proxy | `Standard` — trusts `X-Forwarded-*` headers (correct for internal apps behind LBs) |
| Allowed audiences | `api://<client-id>` always included; add more via `active_directory_v2.allowed_audiences` |

### Minimum viable example

```hcl
# Enables auth with all defaults — no other attributes required.
auth_settings_v2 = {}
```

### Full example (all optional attributes shown)

```hcl
auth_settings_v2 = {
  # Secret/app registration control
  manage_client_secret = true          # default: true when using module app

  # Tenant and access
  aad_allowed_tenants    = "65b3ee68-c495-418b-92ae-82cc5c213c43"  # override if needed
  require_authentication = true
  unauthenticated_action = "RedirectToLoginPage"

  # Login / session behaviour
  token_store_enabled      = true
  logout_endpoint          = "/.auth/logout"
  forward_proxy_convention = "Standard"

  # AAD provider config — omit client_id to use the module-created app registration
  active_directory_v2 = {
    # client_id omitted — module-created app used automatically
    tenant_auth_endpoint       = "https://sts.windows.net/65b3ee68-c495-418b-92ae-82cc5c213c43/v2.0"
    client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
    allowed_audiences          = []  # api://<client-id> is always added on top of this list
  }
}

# Slot-sticky: prevents the secret from swapping with a staging slot
sticky_app_setting_names = ["MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"]
```

### Using an external app registration

Set `active_directory_v2.client_id` explicitly and `manage_client_secret = false`. The module will configure Easy Auth against the external app but will not create or manage the client secret — you must inject `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` via CI/CD or another mechanism.

```hcl
auth_settings_v2 = {
  manage_client_secret = false
  active_directory_v2 = {
    client_id = "1dae6cc4-d745-4073-b7b7-a4a967cd5c59"
  }
}
```

### Client secret rotation

The managed secret has no expiry. To rotate:

```bash
terraform taint 'module.<name>.azuread_application_password.auth_secret[0]'
terraform apply
```

The Key Vault secret and the app setting (KV reference) are updated automatically. The App Service resolves the latest value from Key Vault on the next request without a restart.

### `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET`

When the module manages the secret, this app setting is set to a Key Vault reference (`@Microsoft.KeyVault(SecretUri=...)`). It is also in `lifecycle.ignore_changes` so that external changes (e.g., portal edits or legacy CI/CD injection) are not overwritten by subsequent applies.

## Azure AD Application

### Redirect URIs

The following redirect URIs are registered automatically — no configuration required:

| URI | Condition |
|-----|-----------|
| `https://<default_hostname>/.auth/login/aad/callback` | Always |
| `https://<default_hostname>/signin-oidc` | Always |
| `https://<custom_fqdn>/.auth/login/aad/callback` | Only when `custom_fqdn` is set |
| `https://<custom_fqdn>/signin-oidc` | Only when `custom_fqdn` is set |

Use `redirect_uris` to supply any additional URIs. The most common use case is localhost dev URIs. Because Azure AD does not support wildcard ports, each port must be listed explicitly — agree on a standard dev port per project and commit it to tfvars to avoid manual portal edits:

```hcl
redirect_uris = [
  "https://localhost:7142/signin-oidc",
]
```

### API Permissions (`api_permissions`)

The `api_permissions` variable accepts a flat list of permission objects. The module groups them by `resource_app_id` internally, so the `azuread` provider receives one `required_resource_access` block per API as it requires. You never need to nest permissions yourself:

```hcl
api_permissions = [
  # Microsoft Graph Delegated permissions (resource_app_id omitted — defaults to Graph)
  # 37f7f235-527c-4136-accd-4a02d197296e = openid  | "Sign users in"             | Delegated
  { id = "37f7f235-527c-4136-accd-4a02d197296e", type = "Scope" },
  # 14dad69e-099b-42c9-810b-d002981feec1 = profile | "View users' basic profile" | Delegated
  { id = "14dad69e-099b-42c9-810b-d002981feec1", type = "Scope" },

  # A permission from a different API (resource_app_id required when not Graph)
  { id = "some-permission-guid", type = "Role", resource_app_id = "some-other-api-app-id" },
]
```

**`type` values:**
- `"Scope"` — Delegated permission (the app acts on behalf of a signed-in user)
- `"Role"` — Application permission (the app acts as itself, with no signed-in user)

**`resource_app_id`** defaults to Microsoft Graph (`00000003-0000-0000-c000-000000000000`) when omitted.

#### How to Find a Permission ID

**Azure CLI (recommended):**
```bash
# Delegated permissions (Scope)
az ad sp show --id 00000003-0000-0000-c000-000000000000 \
  --query "oauth2PermissionScopes[?value=='openid']"

# Application permissions (Role)
az ad sp show --id 00000003-0000-0000-c000-000000000000 \
  --query "appRoles[?value=='User.Read.All']"
```

**Azure Portal:**
1. Go to **Azure Active Directory → App Registrations → (any app) → Manifest**
2. Search the JSON for the permission name (e.g., `openid`) to find its GUID
3. Or: **API Permissions → Add a permission → Microsoft Graph**, then hover over any permission — its GUID appears in the tooltip or the request URL

#### Common Microsoft Graph Permission IDs

| GUID | Scope Name | Description | Type |
|------|------------|-------------|------|
| `37f7f235-527c-4136-accd-4a02d197296e` | `openid` | Sign users in | Delegated |
| `14dad69e-099b-42c9-810b-d002981feec1` | `profile` | View users' basic profile | Delegated |
| `e1fe6dd8-ba31-4d61-89e7-88639da4683d` | `User.Read` | Read signed-in user's profile | Delegated |

### Custom Domain FQDN Splitting

When `custom_fqdn` is set, the module splits it into a host portion and a DNS zone name using the following logic:

1. A trailing period is stripped (some DNS tooling appends one)
2. The last `base_domain_labels` labels become `custom_base_domain` (the DNS zone lookup name)
3. Everything before them becomes `custom_host_name` (the CNAME record name)

| `custom_fqdn` | `base_domain_labels` | `custom_host_name` | `custom_base_domain` |
|---|---|---|---|
| `prophix.faithtechinc.com` | `2` (default) | `prophix` | `faithtechinc.com` |
| `myhost.app.domain.com` | `2` (default) | `myhost.app` | `domain.com` |
| `myhost.app.faithtechinc.com` | `3` | `myhost` | `app.faithtechinc.com` |
| `prophix.faithtechinc.com.` | `2` (default) | `prophix` | `faithtechinc.com` |

### Implicit Grant

`implicit_grant_access_token_issuance_enabled` and `implicit_grant_id_token_issuance_enabled` both default to `true`, matching standard Azure AD behavior for hybrid and SPA flows. Set either to `false` to opt out.
