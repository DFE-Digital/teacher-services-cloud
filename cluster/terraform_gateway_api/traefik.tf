resource "helm_release" "traefik_crds" {
  name       = "traefik-crds"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik-crds"
  version    = var.traefik_controller_version
  namespace  = "gateway-api"

  values = [
    file("${path.module}/config/values/traefik-crds.yaml")
  ]

  }


resource "helm_release" "traefik" {

  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_version
  namespace  = "gateway-api"

  depends_on = [
    azurerm_public_ip.traefik-public-ip
  ]

  values = [
    file("${path.module}/config/values/traefik.yaml")
  ]

  # Force the Service to claim your pre-created static public IP
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.spec.loadBalancerIP"
    value = azurerm_public_ip.traefik-public-ip.ip_address
  }

set {
  name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
  value = azurerm_public_ip.traefik-public-ip.resource_group_name
}

  }

resource "kubernetes_namespace" "gateway-api" {
  metadata {
    annotations = {
      name = "gateway-api"
    }

    labels = {
      mylabel = "gateway-api"
    }

    name = "gateway-api"
  }


}

#TRAEFIK CONTROLLER - PUBLIC IP ADDRESS
resource "azurerm_public_ip" "traefik-public-ip" {
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-ingress-pip-traefik"
  location            = data.azurerm_resource_group.resource_group_traefik.location
  resource_group_name = data.azurerm_resource_group.resource_group_traefik.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}

#TRAEFIK CONTROLLER - RESOURCE GROUP
data "azurerm_resource_group" "resource_group_traefik" {
  name = var.resource_group_name
}