terraform {
  required_version = "1.6.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.116.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
  }

  backend "azurerm" {
    container_name = "tsc-tfstate"
    # resource_group_name / storage_account_name etc likely come from env vars in your CI
    # IMPORTANT: set a different key for this root vs the others
    # key = "terraform-istio-base.tfstate"  (or whatever your pattern is)
  }
}