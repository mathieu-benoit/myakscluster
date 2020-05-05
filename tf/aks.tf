resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.aks_name
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg.name
  dns_prefix              = var.aks_name
  kubernetes_version      = var.k8s_version
  #private_cluster_enabled = true

  default_node_pool {
    name            = "system"
    node_count      = 3
    vm_size         = "Standard_DS2_v2"
    type            = "VirtualMachineScaleSets"
    os_disk_size_gb = var.os_disk_size_gb
    vnet_subnet_id  = var.azure_subnet_id
    #node_labels
    #availability_zones
  }

  identity {
    type = "SystemAssigned"
  }
  
  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    load_balancer_sku  = "standard"
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
  }
  
  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
    }
    kube_dashboard {
      enabled = false
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "usernodepool" {
  name                  = "linuxuser"
  os_type               = "linux"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_DS2_v2"
  node_count            = 3
  #node_labels
  #os_disk_size_gb
  #availability_zones
  #vnet_subnet_id
}
