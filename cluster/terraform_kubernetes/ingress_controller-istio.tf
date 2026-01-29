#ISTIO BASE - HELM CHART - CRD'S
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.istio_version
  namespace        = "istio-system"
  create_namespace = true

  values = [
    file("${path.module}/config/istio/values/istio-base-values.yaml")
  ]

}


#ISTIOD - HELM CHART - CONTROL PLANE
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  depends_on = [helm_release.istio_base]
  values = [
    file("${path.module}/config/istio/values/istiod-values.yaml")
  ]

}

#ISTIO INGRESS - HELM CHART - DEPLOYMENT, PODS, SERVICE
resource "helm_release" "istio_ingress" {
  name       = "istio-ingress-gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = "istio-ingress"

  create_namespace = true
  depends_on       = [helm_release.istiod]

  # STATIC VALUES FILE TO LOAD
  values = [
    file("${path.module}/config/istio/values/istio-ingress-values.yaml")
  ]

  # DYNAMIC VALUES TO OVERRIDE STATIC VALUES FILE
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_resource_group.resource_group_istio.name
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-ip-name"
    value = azurerm_public_ip.ingress-public-ip-istio.name
  }

  set {
    name  = "resources.limits.memory"
    value = var.ingress_nginx_memory
    type  = "string"
  }

}

#ISTIO INGRESS - PUBLIC IP ADDRESS
resource "azurerm_public_ip" "ingress-public-ip-istio" {
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-ingress-pip-istio"
  location            = data.azurerm_resource_group.resource_group_istio.location
  resource_group_name = data.azurerm_resource_group.resource_group_istio.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}


#ISTIO INGRESS - RESOURCE GROUP
data "azurerm_resource_group" "resource_group_istio" {
  name = var.resource_group_name
}

#ISTIO INGRESS - GATEWAY RESOURCE
#resource "kubernetes_manifest" "istio_gateway" {
#  manifest = yamldecode(
#    file("${path.module}/config/istio/istio-k8s-resources/gateway.yaml")
#  )

#  depends_on = [
#    helm_release.istio_base,
#    helm_release.istiod,
#    helm_release.istio_ingress
#  ]
#}

#ISTIO INGRESS - SERVICE ACCOUNT RESOURCE
#resource "kubernetes_manifest" "istio_service_account" {
#  manifest = yamldecode(
#    file("${path.module}/config/istio/istio-k8s-resources/service-account.yaml")
#  )

#  depends_on = [
#    helm_release.istio_base,
#    helm_release.istiod,
#    helm_release.istio_ingress
#  ]
#}

#ISTIO INGRESS - AUTH POLICY - PROTECT /metrics ENDPOINT
#resource "kubernetes_manifest" "istio_ingress_auth_policy" {
#  manifest = yamldecode(
#    file("${path.module}/config/istio/istio-k8s-resources/authorization-policy.yaml")
#  )
#}





##### OLD NGINX-CONTROLLER SETTINGS - DIFFICULT TO MAP & NOT REQUIRED UNLESS SPECIFIC ISSUES OCCUR DURING TESTING

# Allow POST requests with large body. Prevent error 413: Request entity too large
#  set {
#    name  = "controller.config.proxy-body-size"
#    value = "50m"
#    type  = "string"
#  }

# Sets the size of the buffer used for reading the first part of the response received from the proxied server.
# Needs to be larger than the response header or nginx will return an error for the request
# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#proxy-buffer-size
#  set {
#    name  = "controller.config.proxy-buffer-size"
#    value = "24k"
#    type  = "string"
#  }

# This ConfigMap setting sets the time, in seconds, during which a keep-alive client connection will stay open on the server side
#  set {
#    name  = "controller.config.keep-alive"
#    value = "120"
#    type  = "auto"
#  }

# This ConfigMap setting defines a timeout for reading client request header, in seconds
#  set {
#    name  = "controller.config.client-header-timeout"
#    value = "120"
#    type  = "auto"
#  }