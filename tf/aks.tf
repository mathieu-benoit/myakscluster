# TODOs:
# Nodepool Mode: https://github.com/terraform-providers/terraform-provider-azurerm/issues/6058

# https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html
resource "azurerm_kubernetes_cluster" "aks" {
  name                     = var.aks_name
  location                 = var.location
  resource_group_name      = azurerm_resource_group.rg.name
  dns_prefix               = var.aks_name
  kubernetes_version       = var.k8s_version
  #private_cluster_enabled = true

  default_node_pool {
    name             = "system"
    node_count       = var.aks_node_count
    vm_size          = var.aks_vm_size
    type             = "VirtualMachineScaleSets"
    vnet_subnet_id   = azurerm_subnet.aks_nodes_subnet.id
    #os_disk_size_gb = var.os_disk_size_gb
    #availability_zones
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
      log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
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
  vm_size               = var.aks_vm_size
  node_count            = var.aks_node_count
  vnet_subnet_id        = azurerm_subnet.aks_nodes_subnet.id #limitation currently with having a different subnet per nodepool, calico netpol not working.
  node_labels           = {
      "kubernetes.azure.com/mode" = "user"
    }
  #os_disk_size_gb
  #availability_zones
}
