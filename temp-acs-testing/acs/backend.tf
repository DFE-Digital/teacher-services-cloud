terraform {
  backend "azurerm" {
    resource_group_name  = "s189d01-tsc-tt-aci-rg"
    storage_account_name = "s189d01tscttacitfstate"
    container_name       = "tfstate"
    key                  = "acs-terraform.tfstate"
  }
}
