resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.4.0"

  # The first part of the name with simple dots is the keys path in the values.yml file e.g. controller.service.annotations
  # The last part is the final key e.g. service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path
  # It may have double escaped dots if the key contains dots e.g. \\.
  # The corresponding value is in the "value" argument
  # https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
    type  = "string"
  }
  # Route requests from the load balancer to the ingress pods on the same node instead of adding one more hop to the node with most pods.
  # This preserves the client IP and removes a hop. It potentially creates a traffic imbalance but this should have no effect for us
  # as we should have many well distributed ingress pods.
  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
    type  = "string"
  }
  set {
    name  = "controller.extraArgs.default-ssl-certificate"
    value = "default/cert-secret"
    type  = "string"
  }
  # Disable HTTP port 80 on the Azure load balancer
  set {
    name  = "controller.service.enableHttp"
    value = "false"
    type  = "auto"
  }
  # Allow POST requests with large body. Prevent error 413: Request entity too large
  set {
    name  = "controller.config.proxy-body-size"
    value = "8m"
    type  = "string"
  }
  set {
    name  = "controller.config.proxy-buffer-size"
    value = "8k"
    type  = "string"
  }
  set {
    name  = "controller.replicaCount"
    value = 20
    type  = "auto"
  }
  set {
    name  = "controller.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }

  # Send x-forwarded-for HTTP header to keep the client IP for the apps
  # When used behind front door, it contains the front door backend IP as well
  set {
    name  = "controller.config.use-forwarded-headers"
    value = "true"
    type  = "string"
  }
  set {
    name  = "controller.config.compute-full-forwarded-for"
    value = "true"
    type  = "string"
  }
  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.public-ip.ip_address
  }
}

resource "helm_release" "ingress-nginx-clone" {
  count    = var.clone_cluster ? 1 : 0
  provider = helm.clone

  name       = helm_release.ingress-nginx.name
  repository = helm_release.ingress-nginx.repository
  chart      = helm_release.ingress-nginx.chart
  version    = helm_release.ingress-nginx.version

  dynamic "set" {
    for_each = helm_release.ingress-nginx.set

    content {
      name  = set.value["name"]
      value = set.value["value"]
      type  = set.value["type"]
    }
  }
}
resource "azurerm_public_ip" "public-ip" {
  name                = "ingres-controller-pip"
  location            = data.azurerm_resource_group.resource-grooup.location
  resource_group_name = data.azurerm_resource_group.resource-grooup.name
  allocation_method   = "Static"
  sku                 = "Standard"

}
data "azurerm_resource_group" "resource-grooup" {
  name = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-rg"
}
