# Comment to bump again (working on module versioning and release automation issues)
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Container Registry
resource "azurerm_container_registry" "this" {
  name                = local.acr_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = true
}

# Key Vault
resource "azurerm_key_vault" "this" {
  name                            = local.kv_name
  location                        = data.azurerm_resource_group.rg.location
  resource_group_name             = data.azurerm_resource_group.rg.name
  sku_name                        = "standard"
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment          = "false"
  enabled_for_template_deployment = "false"
  enabled_for_disk_encryption     = "false"
  rbac_authorization_enabled      = "true"
  public_network_access_enabled   = "false"
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "appservice_keyvault_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.this.identity[0].principal_id
}

resource "azurerm_role_assignment" "appservice_keyvault_cert_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_linux_web_app.this.identity[0].principal_id
}

# This is required to allow the runner to import certificates into the Key Vault
resource "azurerm_role_assignment" "runner_keyvault_cert_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

### See note in https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_certificate
### about needing to assign this role to allow App Service to read certs from Key Vault.
# Get the Azure App Service Resource Provider service principal
data "azuread_service_principal" "microsoft_web_app" {
  client_id = "abfa0a7c-a6b6-4736-8310-5855508787cd" # Well-known App Service RP ID
}

# Grant App Service Resource Provider access to read certificates from Key Vault
resource "azurerm_role_assignment" "appservice_mssp_keyvault_secerts" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azuread_service_principal.microsoft_web_app.object_id
}

resource "azurerm_role_assignment" "appservice_mssp_keyvault_cert" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = data.azuread_service_principal.microsoft_web_app.object_id
}

# Private endpoint for key vault
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${local.kv_name}-pe"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  subnet_id = data.azurerm_subnet.private_link_subnet.id

  private_service_connection {
    name                           = "${local.kv_name}-pe-psc"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = data.azurerm_private_dns_zone.keyvault.name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.keyvault.id]
  }
}

# Storage Account
resource "azurerm_storage_account" "this" {
  name                          = local.sa_name
  resource_group_name           = data.azurerm_resource_group.rg.name
  location                      = data.azurerm_resource_group.rg.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = false
  min_tls_version               = "TLS1_2"

  tags = var.tags
}

# Private endpoint for storage account
resource "azurerm_private_endpoint" "storageaccount" {
  name                = "${local._sa_pe_base}-pe"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  subnet_id = data.azurerm_subnet.private_link_subnet.id

  private_service_connection {
    name                           = "${local._sa_pe_base}-pe-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = data.azurerm_private_dns_zone.storageaccountblob.name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.storageaccountblob.id]
  }
}

# App Service Plan
resource "azurerm_service_plan" "this" {
  name                = "${var.site}-${var.base_name}-plan-${local.env_short}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku

  tags = var.tags
}

# App Service
resource "azurerm_linux_web_app" "this" {
  name                          = "${var.site}-${var.base_name}-app-${local.env_short}"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  service_plan_id               = azurerm_service_plan.this.id
  public_network_access_enabled = false
  virtual_network_subnet_id     = data.azurerm_subnet.vnet_integration.id
  https_only                    = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                                     = var.site_config.always_on
    container_registry_managed_identity_client_id = var.site_config.container_registry_managed_identity_client_id
    container_registry_use_managed_identity       = var.site_config.container_registry_use_managed_identity
    ftps_state                                    = var.site_config.ftps_state
    health_check_path                             = var.site_config.health_check_path
    health_check_eviction_time_in_min             = var.site_config.health_check_eviction_time_in_min
    http2_enabled                                 = var.site_config.http2_enabled
    minimum_tls_version                           = var.site_config.minimum_tls_version
    remote_debugging_enabled                      = var.site_config.remote_debugging_enabled
    remote_debugging_version                      = var.site_config.remote_debugging_version
    scm_minimum_tls_version                       = var.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction                   = var.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                             = var.site_config.use_32_bit_worker
    vnet_route_all_enabled                        = coalesce(var.site_config.vnet_route_all_enabled, true)
    websockets_enabled                            = var.site_config.websockets_enabled
    worker_count                                  = var.site_config.worker_count

    application_stack {
      docker_image_name        = coalesce(var.application_stack.docker_image_name, "placeholder/image:tag")
      docker_registry_url      = var.application_stack.docker_registry_url != null ? var.application_stack.docker_registry_url : "https://${azurerm_container_registry.this.login_server}"
      docker_registry_username = var.application_stack.docker_registry_username != null ? var.application_stack.docker_registry_username : azurerm_container_registry.this.admin_username
      docker_registry_password = var.application_stack.docker_registry_password != null ? var.application_stack.docker_registry_password : azurerm_container_registry.this.admin_password
    }
  }

  lifecycle {
    ignore_changes = [
      site_config[0].application_stack[0].docker_image_name,
      # When the module manages the client secret (KV reference), the value is stable after first
      # apply. When CI/CD injects it externally, this prevents Terraform from clearing it.
      app_settings["MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"],
    ]
  }

  app_settings = merge(
    {
      "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
      "ASPNETCORE_ENVIRONMENT"              = local.env_long
      "KeyVaultName"                        = azurerm_key_vault.this.name
      "ENV"                                 = title(local.env_med)
      "ASPNETCORE_FORWARDEDHEADERS_ENABLED" = "true"
    },
    # When auth_settings_v2 is enabled, write the allowed-tenants app setting automatically.
    local._auth_enabled ? {
      "WEBSITE_AUTH_AAD_ALLOWED_TENANTS" = coalesce(try(var.auth_settings_v2.aad_allowed_tenants, null), data.azurerm_client_config.current.tenant_id)
    } : {},
    # When the module manages the client secret, wire it up as a Key Vault reference.
    local._manage_auth_secret ? {
      (local._auth_secret_setting_name) = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.auth_client_secret[0].versionless_id})"
    } : {},
    var.app_settings
  )

  dynamic "auth_settings_v2" {
    for_each = local._auth_enabled ? [var.auth_settings_v2] : []
    content {
      auth_enabled             = true
      default_provider         = "azureactivedirectory"
      require_authentication   = auth_settings_v2.value.require_authentication
      require_https            = true
      unauthenticated_action   = auth_settings_v2.value.unauthenticated_action
      forward_proxy_convention = auth_settings_v2.value.forward_proxy_convention

      active_directory_v2 {
        # Use the module-created app registration unless the caller supplied an explicit client_id.
        client_id = coalesce(
          try(auth_settings_v2.value.active_directory_v2.client_id, null),
          azuread_application.app.client_id
        )
        tenant_auth_endpoint       = coalesce(try(auth_settings_v2.value.active_directory_v2.tenant_auth_endpoint, null), "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/v2.0")
        client_secret_setting_name = coalesce(try(auth_settings_v2.value.active_directory_v2.client_secret_setting_name, null), "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET")
        # api://<client-id> is always included so the app can validate tokens issued to its own audience.
        allowed_audiences = toset(concat(
          ["api://${coalesce(try(auth_settings_v2.value.active_directory_v2.client_id, null), azuread_application.app.client_id)}"],
          try(auth_settings_v2.value.active_directory_v2.allowed_audiences, [])
        ))
      }

      login {
        token_store_enabled = auth_settings_v2.value.token_store_enabled
        logout_endpoint     = auth_settings_v2.value.logout_endpoint
      }
    }
  }

  dynamic "sticky_settings" {
    for_each = length(var.sticky_app_setting_names) > 0 ? [var.sticky_app_setting_names] : []
    content {
      app_setting_names = sticky_settings.value
    }
  }

  tags = var.tags
}

# private endpoint for app service
resource "azurerm_private_endpoint" "appservice" {
  name                = "${var.site}-${var.base_name}-app-pe-${local.env_short}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  subnet_id = data.azurerm_subnet.private_link_subnet.id

  private_service_connection {
    name                           = "${var.site}-${var.base_name}-app-pe-psc-${local.env_short}"
    private_connection_resource_id = azurerm_linux_web_app.this.id
    is_manual_connection           = false
    subresource_names              = ["sites"]

  }

  private_dns_zone_group {
    name                 = data.azurerm_private_dns_zone.azurewebsites.name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.azurewebsites.id]
  }
}

##############################
### CUSTOM DOMAIN (OPTIONAL) ###
##############################

# App Service custom hostname binding
resource "azurerm_dns_cname_record" "custom_hostname" {
  count               = local.deploy_custom_domain ? 1 : 0
  name                = local.custom_host_name
  zone_name           = data.azurerm_dns_zone.custom[0].name
  resource_group_name = data.azurerm_dns_zone.custom[0].resource_group_name
  ttl                 = 300
  record              = azurerm_linux_web_app.this.default_hostname
}

resource "azurerm_app_service_custom_hostname_binding" "custom_hostname" {
  count               = local.deploy_custom_domain ? 1 : 0
  hostname            = var.custom_fqdn
  app_service_name    = azurerm_linux_web_app.this.name
  resource_group_name = data.azurerm_resource_group.rg.name

  depends_on = [azurerm_dns_cname_record.custom_hostname]
}

##############################
### CERTIFICATE MANAGEMENT ###
##############################

resource "azurerm_dns_txt_record" "cert_validation" {
  count               = local.deploy_custom_domain ? 1 : 0
  name                = join(".", ["asuid", azurerm_dns_cname_record.custom_hostname[0].name, data.azurerm_dns_zone.custom[0].name])
  zone_name           = data.azurerm_dns_zone.custom[0].name
  resource_group_name = data.azurerm_dns_zone.custom[0].resource_group_name
  ttl                 = 300
  record {
    value = azurerm_linux_web_app.this.custom_domain_verification_id
  }
}

resource "azurerm_app_service_managed_certificate" "custom_cert" {
  count                      = local.deploy_custom_domain ? 1 : 0
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.custom_hostname[0].id
}

resource "azurerm_app_service_certificate_binding" "custom_cert_binding" {
  count               = local.deploy_custom_domain ? 1 : 0
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.custom_hostname[0].id
  certificate_id      = azurerm_app_service_managed_certificate.custom_cert[0].id
  ssl_state           = "SniEnabled"
}

##############################
### AZURE AD APPLICATION ###
##############################

# Azure AD Application (Service Principal for SSO and Graph API Access)
resource "azuread_application" "app" {
  display_name     = "${var.site}-${var.base_name}-${local.env_short}"
  sign_in_audience = "AzureADMyOrg"

  web {
    redirect_uris = toset(concat(
      [
        # Default redirect URIs on the app service default hostname.
        # Uses a computed local (not the resource attribute) to avoid a dependency cycle when
        # auth is enabled — see the _web_app_default_hostname local in variables.tf.
        "https://${local._web_app_default_hostname}/.auth/login/aad/callback",
        "https://${local._web_app_default_hostname}/signin-oidc",
      ],
      # /.auth/login/aad/callback and /signin-oidc on the custom hostname, when a custom domain is configured
      local.deploy_custom_domain ? [
        "https://${var.custom_fqdn}/.auth/login/aad/callback",
        "https://${var.custom_fqdn}/signin-oidc",
      ] : [],
      # Caller-supplied URIs (e.g., localhost dev URIs: "https://localhost:7142/signin-oidc")
      var.redirect_uris
    ))

    implicit_grant {
      access_token_issuance_enabled = var.implicit_grant_access_token_issuance_enabled
      id_token_issuance_enabled     = var.implicit_grant_id_token_issuance_enabled
    }
  }

  dynamic "required_resource_access" {
    for_each = local.api_permissions_grouped
    content {
      resource_app_id = required_resource_access.key

      dynamic "resource_access" {
        for_each = required_resource_access.value
        content {
          id   = resource_access.value.id
          type = resource_access.value.type
        }
      }
    }
  }
}

resource "azuread_service_principal" "sp" {
  client_id = azuread_application.app.client_id
}

##############################
### AUTH CLIENT SECRET (OPTIONAL) ###
##############################

# Created only when auth_settings_v2 is enabled and no external client_id is supplied
# (or when manage_client_secret = true is set explicitly).

# The client secret for the Azure AD application used by Easy Auth.
# No end_date set — secret does not expire. To rotate: terraform taint
# 'module.<name>.azuread_application_password.auth_secret[0]' then apply.
resource "azuread_application_password" "auth_secret" {
  count          = local._manage_auth_secret ? 1 : 0
  application_id = azuread_application.app.id
  display_name   = "easy-auth"
}

# Grant the Terraform runner Secrets Officer so it can write the secret to Key Vault.
resource "azurerm_role_assignment" "runner_keyvault_secrets_officer" {
  count                = local._manage_auth_secret ? 1 : 0
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait for the private endpoint DNS record to propagate through Infoblox → Azure DNS Private
# Resolver before attempting to write to the Key Vault data plane. Without this, a first-time
# apply creates the PE and immediately resolves the KV hostname to the public IP (not yet in
# DNS cache), hitting the public endpoint and receiving a 403 ForbiddenByConnection.
resource "time_sleep" "keyvault_pe_dns_propagation" {
  count           = local._manage_auth_secret ? 1 : 0
  create_duration = "60s"
  depends_on      = [azurerm_private_endpoint.keyvault]
}

# Store the client secret in Key Vault so the App Service reads it via a KV reference.
resource "azurerm_key_vault_secret" "auth_client_secret" {
  count        = local._manage_auth_secret ? 1 : 0
  name         = "auth-client-secret"
  value        = azuread_application_password.auth_secret[0].value
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [
    azurerm_role_assignment.runner_keyvault_secrets_officer,
    time_sleep.keyvault_pe_dns_propagation,
  ]
}
