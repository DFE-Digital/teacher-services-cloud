terraform {
  required_version = "= 1.14.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.61.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "2.9.0"
    }
  }

  backend "azurerm" {
    container_name = "tsc-tfstate"
    #storage_account_name = "s189d01tsctfstatedv"
    #resource_group_name = "s189d01-tsc-dv-rg"
    #key                  = "development_alerting.tfstate"
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

provider "azapi" {

}
