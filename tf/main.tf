# https://github.com/terraform-providers/terraform-provider-azurerm
provider "azurerm" {
  version = "=2.15.0"
  features {}
}

# https://www.terraform.io/docs/providers/azuread/index.html
provider "azuread" {
  version = "=0.10.0"
}

provider "external" {
  version = "=1.2.0"
}

provider "random" {
  version = "=2.2.1"
}

# https://www.terraform.io/docs/providers/ado/index.html
/*provider "azuredevops" {
  version = "=0.0.1"
}*/

data "azurerm_client_config" "current" {}

# TODO: Terraform State in Blog storage account access (vnet peering + vnet link in private dns)
