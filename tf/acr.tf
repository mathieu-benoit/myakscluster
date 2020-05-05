# https://www.terraform.io/docs/providers/azurerm/r/container_registry.html
resource "azurerm_container_registry" "acr" {
  name                = var.aks_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false
  # network_rule_set = {
  #   default_action          = Deny
  # }
  # virtual_network = {
  #   subnet_id               = azurerm_subnet.aksnet.id
  # }
}

# https://www.terraform.io/docs/providers/azurerm/r/role_assignment.html
resource "azurerm_role_assignment" "aksacrrole" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "acrpull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id
}
