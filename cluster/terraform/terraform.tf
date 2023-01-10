terraform {
  required_version = "~> 1.3.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.25.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.8.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.16.1"
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

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
}
