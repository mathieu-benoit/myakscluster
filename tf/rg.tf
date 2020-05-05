# https://www.terraform.io/docs/providers/azurerm/r/resource_group.html
resource "azurerm_resource_group" "rg" {
  name     = var.aks_name
  location = var.location
}

# https://www.terraform.io/docs/providers/azurerm/r/management_lock.html
resource "azurerm_management_lock" "lock" {
  name       = "CanNotDelete"
  scope      = azurerm_resource_group.rg.id
  lock_level = "CanNotDelete"
  notes      = "This Resource Group and its Resources can't be deleted."
}
