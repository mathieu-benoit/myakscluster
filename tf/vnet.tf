# https://www.terraform.io/docs/providers/azurerm/r/virtual_network.html
resource "azurerm_virtual_network" "vnet" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.virtual_network_address_prefix]
}

# https://www.terraform.io/docs/providers/azurerm/r/subnet.html
resource "azurerm_subnet" "aks_nodes_subnet" {
  name                 = "aks_nodes_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_nodes_subnet_address_prefix]
}

resource "azurerm_subnet" "aks_ingress_subnet" {
  name                 = "aks_ingress_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_ingress_subnet_address_prefix]
}
