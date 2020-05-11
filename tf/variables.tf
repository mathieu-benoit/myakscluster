variable "aks_name" {
  description = "Name of the AKS service name and all other Azure services associated to it: resource group, vnet, etc."
}

# Variables below are the default values which will be used as-is or could be potentially overriden:

variable "k8s_version" {
  type        = string
  default     = "1.16.7"
  description = "The K8S version."
}

variable "location" {
  type        = string
  default     = "canadacentral"
  description = "Location of the resources."
}

variable "aks_vnet_address_prefix" {
  type        = string
  default     = "100.64.0.0/21"
  description = "The VNET's IP ranges, /21 represents 2048 IPs."
}

variable "aks_nodes_subnet_address_prefix" {
  type        = string
  default     = "100.64.0.0/23"
  description = "The AKS Nodes Subnet's IP ranges, /23 represents 512 IPs."
}

variable "aks_ingress_subnet_address_prefix" {
  type        = string
  default     = "100.64.2.0/24"
  description = "The AKS Ingress/Service Subnet's IP ranges, /24 represents 256 IPs."
}

variable "acr_subnet_address_prefix" {
  type        = string
  default     = "100.64.3.0/27"
  description = "The ACR Subnet's IP ranges, /27 represents 32 IPs."
}

variable "aks_docker_bridge_cidr" {
  type        = string
  default     = "172.17.0.1/27"
  description = "The K8S's Docker bridge CIDR, /27 represents 32 IPs."
}

variable "aks_service_cidr" {
  type        = string
  default     = "192.168.0.0/24"
  description = "The K8S's Service CIDR, /24 represents 256 IPs."
}

variable "aks_dns_service_ip" {
  type        = string
  default     = "192.168.0.10"
  description = "The K8S's DNS Service IP, /24 represents 256 IPs."
}

variable "aks_vm_size" {
  type        = string
  default     = "Standard_DS2_v2"
  description = "The size of the AKS's nodes/VMs."
}

variable "aks_network_policy" {
  type        = string
  default     = "calico"
  description = "The AKS's network policy."
}

variable "aks_node_count" {
  type        = number
  default     = 3
  description = "The number of nodes/VMs per nodepool."
}

variable "aks_availability_zones" {
  type        = list(string)
  default     = []
  #default     = ["1", "2", "3"]
  description = "The AZs for the AKS's nodes/VMs."
}

variable "jb_vnet_address_prefix" {
  type        = string
  default     = "10.1.0.0/26"
  description = "The VNET's IP ranges, /26 represents 64 IPs."
}

variable "jb_subnet_address_prefix" {
  type        = string
  default     = "10.1.0.0/27"
  description = "The Jumpbox Subnet's IP ranges, /27 represents 32 IPs."
}

variable "bastion_subnet_address_prefix" {
  type        = string
  default     = "10.1.0.32/27"
  description = "The Bastion Subnet's IP ranges, /27 represents 32 IPs."
}