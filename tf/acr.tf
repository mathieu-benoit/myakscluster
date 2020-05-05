resource "azurerm_container_registry" "acr" {
  name                = var.aks_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false
}
