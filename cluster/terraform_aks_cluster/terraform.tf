terraform {
  required_version = "~> 1.3.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.46.0"
    }
  }
  backend "azurerm" {
    container_name = "tsc-tfstate"
  }
}

provider "azurerm" {
  subscription_id = try(local.azure_credentials.subscriptionId, null)
  client_id       = try(local.azure_credentials.clientId, null)
  client_secret   = try(local.azure_credentials.clientSecret, null)
  tenant_id       = try(local.azure_credentials.tenantId, null)
  features {}

  skip_provider_registration = true
}
