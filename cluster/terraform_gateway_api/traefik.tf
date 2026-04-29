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



##########

  set {
    name  = "service.spec.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.spec.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-pip-name"
    value = azurerm_public_ip.traefik-public-ip.name
    type  = "string"
  }

  # Resource group of the ingress public IP
  # The cluster managed identity must have Network Contributor role on the resource group
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_resource_group.resource_group_traefik.name
    type  = "string"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
    type  = "string"
  }

#####################


  set {
    name  = "resources.limits.memory"
    value = var.ingress_nginx_memory
    type  = "string"
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