resource "azurerm_resource_group" "rg" {
  name     = var.aks_name
  location = var.location
}

/*
resource "azurerm_management_lock" "lock" {
  name       = "CanNotDelete"
  scope      = azurerm_resource_group.rg.id
  lock_level = "CanNotDelete"
  notes      = "This Resource Group and its Resources can't be deleted."
}
*/
