resource "helm_release" "traefik-ingress" {
  count = var.enable_traefik ? 1 : 0

  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_ingress_version
  namespace  = "traefik"
  values = [
    file("${path.module}/config/traefik/${var.config}.values.yaml")
  ]

  set {
    name  = "service.spec.externalTrafficPolicy"
    value = "Local"
  }
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-pip-name"
    value = azurerm_public_ip.ingress-public-ip-traefik[0].name
    type  = "string"
  }
  # Resource group of the ingress public IP
  # The cluster managed identity must have Network Contributor role on the resource group
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_resource_group.resource_group.name
    type  = "string"
  }
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
    type  = "string"
  }

}

resource "azurerm_public_ip" "ingress-public-ip-traefik" {
  count = var.add_traefik_ingress_ip ? 1 : 0

  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-traefik-ingress-pip"
  location            = data.azurerm_resource_group.resource_group.location
  resource_group_name = data.azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  timeouts {}

  lifecycle { ignore_changes = [tags] }
}

resource "kubernetes_ingress_class" "nginx" {
  count = var.create_nginx_ingressclass ? 1 : 0

  metadata {
    name = "nginx"
    labels = {
      "app.kubernetes.io/name" = "ingress-nginx"
    }
  }

  spec {
    controller = "k8s.io/ingress-nginx"
  }

}
