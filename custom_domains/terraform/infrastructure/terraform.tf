terraform {
  required_version = "= 1.14.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.61.0"
    }
  }
  backend "azurerm" {
    container_name = "tscdomains-tfstate"
    key            = "tscdomains.tfstate"
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
