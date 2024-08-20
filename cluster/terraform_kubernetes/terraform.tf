terraform {
  required_version = "1.6.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.116.0"
    }
    environment = {
      source  = "EppO/environment"
      version = "1.3.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
    statuscake = {
      source  = "StatusCakeDev/statuscake"
      version = "2.2.2"
    }
  }

  backend "azurerm" {
    container_name = "tsc-tfstate"
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

data "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  resource_group_name = var.resource_group_name
}

data "azurerm_kubernetes_cluster" "clone" {
  count = var.clone_cluster ? 1 : 0

  name                = local.clone_cluster_name
  resource_group_name = var.resource_group_name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  client_certificate     = local.rbac_enabled ? null : base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
  client_key             = local.rbac_enabled ? null : base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)

  dynamic "exec" {
    for_each = local.rbac_enabled ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = local.kubelogin_args
    }
  }
}

provider "kubernetes" {
  alias                  = "clone"
  host                   = try(data.azurerm_kubernetes_cluster.clone[0].kube_config[0].host, null)
  cluster_ca_certificate = try(base64decode(data.azurerm_kubernetes_cluster.clone[0].kube_config[0].cluster_ca_certificate), null)
  client_certificate     = local.rbac_enabled_clone ? null : try(base64decode(data.azurerm_kubernetes_cluster.clone[0].kube_config[0].client_certificate), null)
  client_key             = local.rbac_enabled_clone ? null : try(base64decode(data.azurerm_kubernetes_cluster.clone[0].kube_config[0].client_key), null)

  dynamic "exec" {
    for_each = local.rbac_enabled_clone ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = local.kubelogin_args
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
    client_certificate     = local.rbac_enabled ? null : base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    client_key             = local.rbac_enabled ? null : base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)

    dynamic "exec" {
      for_each = local.rbac_enabled ? [1] : []
      content {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "kubelogin"
        args        = local.kubelogin_args
      }
    }
  }
}

provider "helm" {
  alias = "clone"
  kubernetes {
    host                   = try(data.azurerm_kubernetes_cluster.clone[0].kube_config[0].host, null)
    cluster_ca_certificate = try(base64decode(data.azurerm_kubernetes_cluster.clone[0].kube_config[0].cluster_ca_certificate), null)
    client_certificate     = local.rbac_enabled_clone ? null : try(base64decode(data.azurerm_kubernetes_cluster.clone[0].kube_config[0].client_certificate), null)
    client_key             = local.rbac_enabled_clone ? null : try(base64decode(data.azurerm_kubernetes_cluster.clone[0].kube_config[0].client_key), null)

    dynamic "exec" {
      for_each = local.rbac_enabled_clone ? [1] : []
      content {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "kubelogin"
        args        = local.kubelogin_args
      }
    }
  }
}

provider "statuscake" {
  api_token = local.api_token
}
