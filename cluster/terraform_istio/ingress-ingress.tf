#ISTIO INGRESS - HELM CHART - DEPLOYMENT, PODS, SERVICE
resource "helm_release" "istio_ingress" {
  name       = "istio-ingress-gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = "istio-ingress"

  wait            = true
  wait_for_jobs   = true
  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  create_namespace = true
  depends_on       = [helm_release.istiod]

  # STATIC VALUES FILE TO LOAD
  values = [
    file("${path.module}/config/values/istio-ingress-values.yaml")
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
    value = var.istio_gateway_pod_memory
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
