# https://www.terraform.io/docs/providers/azuread/r/application.html
resource "azuread_application" "sp_kv_list" {
  name = "${var.aks_name}-kvlist"
}

# https://www.terraform.io/docs/providers/azuread/r/service_principal.html
resource "azuread_service_principal" "sp_kv_list" {
  application_id = azuread_application.sp_kv_list.application_id
}

# https://www.terraform.io/docs/providers/random/r/password.html
resource "random_password" "sp_kv_list" {
  length  = 24
  special = true
  min_numeric = 1
  min_special = 1
}

# https://www.terraform.io/docs/providers/azuread/r/service_principal_password.html
resource "azuread_service_principal_password" "sp_kv_list" {
  service_principal_id = azuread_service_principal.sp_kv_list.id
  value                = random_password.sp_kv_list.result
  end_date             = var.sp_password_end_date
}

# https://www.terraform.io/docs/providers/azurerm/r/key_vault_access_policy.html
resource "azurerm_key_vault_access_policy" "kv_access_policy_list_secrets" {
  key_vault_id = azurerm_key_vault.kv.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azuread_service_principal.sp_kv_list.object_id

  secret_permissions = [
      "list",
    ]
}

# https://github.com/microsoft/terraform-provider-azuredevops/blob/master/website/docs/d/data_projects.html.markdown
/*data "azuredevops_project" "ado_project" {
  project_name       = "MyOwnBacklog"
}

# https://github.com/microsoft/terraform-provider-azuredevops/blob/master/website/docs/r/serviceendpoint_azurerm.html.markdown
resource "azuredevops_serviceendpoint_azurerm" "endpointazure" {
  project_id                = azuredevops_project.ado_project.project_id
  service_endpoint_name     = "${var.aks_name}-kvlist"

  credentials {
    serviceprincipalid      = azuread_service_principal.sp_kv_list.application_id
    serviceprincipalkey     = random_password.sp_kv_list.result
  }

  azurerm_spn_tenantid      = data.azurerm_client_config.current.tenant_id
  azurerm_subscription_id   = data.azurerm_client_config.current.subscription_id
  azurerm_subscription_name = "Sample Subscription"
}*/

# Otherwise use this https://www.terraform.io/docs/providers/null/resource.html to levarage the ADO CLI instead

output "sp_kv_list_application_id" {
  description = "KeyVault list SP's applicationid for Service Endpoint in Azure DevOps."
  value       = azuread_service_principal.sp_kv_list.application_id
}

output "sp_kv_list_secret" {
  description = "KeyVault list SP's secret for Service Endpoint in Azure DevOps."
  value       = random_password.sp_kv_list.result
}