# TODOs:
# Current limitation with just one Private IP available: https://github.com/terraform-providers/terraform-provider-azurerm/issues/6571

# https://www.terraform.io/docs/providers/azurerm/r/subnet.html
resource "azurerm_subnet" "subnet_acr" {
  name                                           = "subnet_acr"
  resource_group_name                            = azurerm_resource_group.rg_aks.name
  virtual_network_name                           = azurerm_virtual_network.vnet_aks.name
  address_prefixes                               = [var.acr_subnet_address_prefix]
  enforce_private_link_endpoint_network_policies = true
}

# https://www.terraform.io/docs/providers/azurerm/r/container_registry.html
resource "azurerm_container_registry" "acr" {
  name                = var.aks_name
  resource_group_name = azurerm_resource_group.rg_aks.name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false

  network_rule_set    {
    default_action = "Deny"
  }

  # virtual_network   = {
  #   subnet_id = azurerm_subnet.aksnet.id
  # }
}

# https://www.terraform.io/docs/providers/azurerm/r/private_dns_zone.html
resource "azurerm_private_dns_zone" "private_dns_acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg_aks.name
}

# https://www.terraform.io/docs/providers/azurerm/r/private_dns_zone_virtual_network_link.html
resource "azurerm_private_dns_zone_virtual_network_link" "private_link_aks_acr" {
  name                  = var.aks_name
  resource_group_name   = azurerm_resource_group.rg_aks.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_acr.name
  virtual_network_id    = azurerm_virtual_network.vnet_aks.id
  registration_enabled  = false
}

locals {
  acr_private_endpoint_name = format("%s-acr", var.aks_name)
}

# https://www.terraform.io/docs/providers/azurerm/r/private_endpoint.html
resource "azurerm_private_endpoint" "private_endpoint_acr" {
  name                = local.acr_private_endpoint_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_aks.name
  subnet_id           = azurerm_subnet.subnet_acr.id

  private_service_connection {
    name                           = local.acr_private_endpoint_name
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }
}

# https://www.terraform.io/docs/providers/external/data_source.html
data "external" "get_acr_private_endpoint_private_ip" {
  program = ["/bin/sh", "${path.module}/getAcrPrivateEndpointPrivateIp.sh"]

  query = {
    rg                  = azurerm_resource_group.rg_aks.name
    privateEndpointName = azurerm_private_endpoint.private_endpoint_acr.name
  }
}

# https://www.terraform.io/docs/providers/azurerm/r/private_dns_a_record.html
resource "azurerm_private_dns_a_record" "private_dns_a_record_acr" {
  name                = var.aks_name
  zone_name           = azurerm_private_dns_zone.private_dns_acr.name
  resource_group_name = azurerm_resource_group.rg_aks.name
  ttl                 = 300
  records             = [data.external.get_acr_private_endpoint_private_ip.result.acr_private_endpoint_private_ip]
}

resource "azurerm_private_dns_a_record" "private_dns_a_record_acr_data" {
  name                = "${var.aks_name}.${var.location}.data"
  zone_name           = azurerm_private_dns_zone.private_dns_acr.name
  resource_group_name = azurerm_resource_group.rg_aks.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.private_endpoint_acr.private_service_connection[0].private_ip_address]
}

# https://www.terraform.io/docs/providers/azurerm/r/role_assignment.html
resource "azurerm_role_assignment" "role_aks_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "acrpull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id
}
