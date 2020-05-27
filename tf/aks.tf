# TODOs:
# Nodepool Mode: https://github.com/terraform-providers/terraform-provider-azurerm/issues/6058

# https://www.terraform.io/docs/providers/azurerm/r/resource_group.html
resource "azurerm_resource_group" "rg_aks" {
  name     = var.aks_name
  location = var.location
}

# https://www.terraform.io/docs/providers/azurerm/r/management_lock.html
/*resource "azurerm_management_lock" "lock_rg_aks" {
  name       = "CanNotDelete"
  scope      = azurerm_resource_group.rg_aks.id
  lock_level = "CanNotDelete"
  notes      = "This Resource Group and its Resources can't be deleted."
}*/

# https://www.terraform.io/docs/providers/azurerm/r/virtual_network.html
resource "azurerm_virtual_network" "vnet_aks" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_aks.name
  address_space       = [var.aks_vnet_address_prefix]
}

# https://www.terraform.io/docs/providers/azurerm/r/subnet.html
resource "azurerm_subnet" "subnet_aks_nodes" {
  name                 = "subnet_aks_nodes"
  resource_group_name  = azurerm_resource_group.rg_aks.name
  virtual_network_name = azurerm_virtual_network.vnet_aks.name
  address_prefixes     = [var.aks_nodes_subnet_address_prefix]
}

resource "azurerm_subnet" "subnet_aks_ingress" {
  name                 = "subnet_aks_ingress"
  resource_group_name  = azurerm_resource_group.rg_aks.name
  virtual_network_name = azurerm_virtual_network.vnet_aks.name
  address_prefixes     = [var.aks_ingress_subnet_address_prefix]
}

#resource "azurerm_role_assignment" "role_aks_subnet" {
#  scope                = var.vnet_subnet_id
#  role_definition_name = "Network Contributor"
#  principal_id         = azuread_service_principal.aks.id
#}

# https://www.terraform.io/docs/providers/azurerm/r/log_analytics_workspace.html
resource "azurerm_log_analytics_workspace" "law_aks" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_aks.name
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "las_aks" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg_aks.name
  workspace_resource_id = azurerm_log_analytics_workspace.law_aks.id
  workspace_name        = azurerm_log_analytics_workspace.law_aks.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

# https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html
resource "azurerm_kubernetes_cluster" "aks" {
  name                     = var.aks_name
  location                 = var.location
  resource_group_name      = azurerm_resource_group.rg_aks.name
  dns_prefix               = var.aks_name
  kubernetes_version       = var.k8s_version
  private_cluster_enabled  = true

  default_node_pool {
    name               = "system"
    node_count         = var.aks_node_count
    vm_size            = var.aks_node_size
    type               = "VirtualMachineScaleSets"
    vnet_subnet_id     = azurerm_subnet.subnet_aks_nodes.id
    availability_zones = var.aks_availability_zones
    os_disk_size_gb    = var.aks_os_disk_size
  }

  identity {
    type = "SystemAssigned"
  }
  
  network_profile {
    network_plugin     = "azure"
    network_policy     = var.aks_network_policy
    load_balancer_sku  = "standard"
    service_cidr       = var.aks_service_cidr
    dns_service_ip     = var.aks_dns_service_ip
    docker_bridge_cidr = var.aks_docker_bridge_cidr
    #FYI: pod_cidr should be defined if kubenet is use.
  }
  
  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.law_aks.id
    }
    kube_dashboard {
      enabled = false
    }
  }
}

# https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster_node_pool.html
resource "azurerm_kubernetes_cluster_node_pool" "linuxusernodepool" {
  name                  = "userlinux"
  os_type               = "Linux"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.aks_node_size
  node_count            = var.aks_node_count
  vnet_subnet_id        = azurerm_subnet.subnet_aks_nodes.id #limitation currently with having a different subnet per nodepool, calico netpol not working.
  node_labels           = {
      "kubernetes.azure.com/mode" = "user"
    }
  availability_zones    = var.aks_availability_zones
  os_disk_size_gb       = var.aks_os_disk_size
}
