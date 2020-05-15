# https://www.terraform.io/docs/providers/azuread/r/application.html
resource "azuread_application" "sp_acr_push" {
  name = "${var.aks_name}-acrpush"
}

resource "azuread_application" "sp_aks_user" {
  name = "${var.aks_name}-aksuser"
}

# https://www.terraform.io/docs/providers/azuread/r/service_principal.html
resource "azuread_service_principal" "sp_acr_push" {
  application_id = azuread_application.sp_acr_push.application_id
}

resource "azuread_service_principal" "sp_aks_user" {
  application_id = azuread_application.sp_aks_user.application_id
}

# https://www.terraform.io/docs/providers/random/r/password.html
resource "random_password" "sp_acr_push" {
  length  = 24
  special = true
  min_numeric = 1
  min_special = 1
}

resource "random_password" "sp_aks_user" {
  length  = 24
  special = true
  min_numeric = 1
  min_special = 1
}

# https://www.terraform.io/docs/providers/azuread/r/service_principal_password.html
resource "azuread_service_principal_password" "sp_acr_push" {
  service_principal_id = azuread_service_principal.sp_acr_push.id
  value                = random_password.sp_acr_push.result
  end_date             = "2099-01-01T01:02:03Z"
}

resource "azuread_service_principal_password" "sp_aks_user" {
  service_principal_id = azuread_service_principal.sp_aks_user.id
  value                = random_password.sp_aks_user.result
  end_date             = "2099-01-01T01:02:03Z"
}

# https://www.terraform.io/docs/providers/azurerm/r/role_assignment.html
resource "azurerm_role_assignment" "sp_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "acrpush"
  principal_id         = azuread_service_principal.sp_acr_push.object_id
}

resource "azurerm_role_assignment" "sp_aks_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.sp_aks_user.object_id
}

data "azurerm_client_config" "current" {}

# https://www.terraform.io/docs/providers/azurerm/r/key_vault.html
resource "azurerm_key_vault" "kv" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_aks.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"
}

# https://www.terraform.io/docs/providers/azurerm/r/key_vault_access_policy.html
resource "azurerm_key_vault_access_policy" "kv_access_policy_set_secrets" {
  key_vault_id = azurerm_key_vault.kv.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
      "set",
      "get",
      "delete",
    ]
}

# https://www.terraform.io/docs/providers/azurerm/r/key_vault_secret.html
resource "azurerm_key_vault_secret" "sp_login_acr_push" {
  name         = "registryLogin"
  value        = azuread_service_principal.sp_acr_push.application_id
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "sp_password_acr_push" {
  name         = "registryPassword"
  value        = random_password.sp_acr_push.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "acr_name" {
  name         = "registryName"
  value        = azurerm_container_registry.acr.name
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "sp_login_aks_user" {
  name         = "aksSpId"
  value        = azuread_service_principal.sp_aks_user.application_id
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "sp_password_aks_user" {
  name         = "aksSpSecret"
  value        = random_password.sp_aks_user.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "sp_tenant_id_aks_user" {
  name         = "aksSpTenantId"
  value        = data.azurerm_client_config.current.tenant_id
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "aks_name_aks_user" {
  name         = "aksName"
  value        = azurerm_kubernetes_cluster.aks.name
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "aks_rg_name_aks_user" {
  name         = "aksResourceGroupName"
  value        = azurerm_resource_group.rg_aks.name
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "aks_location_aks_user" {
  name         = "aksLocation"
  value        = var.location
  key_vault_id = azurerm_key_vault.kv.id
}