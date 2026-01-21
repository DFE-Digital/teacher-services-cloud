#CREATE CRD'S
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_version
  namespace  = "istio-system"
  create_namespace = true

  values = [
    file("${path.module}/config/istio/istio-base-values.yaml")
  ]

}


# CREATE VS TO ROUTE TRAFFIC FROM
resource "kubernetes_manifest" "istio_virtual_service" {
  manifest = yamldecode(
    file("${path.module}/config/istio/virtual-service.yaml")
  )
}


resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  depends_on = [helm_release.istio_base]
  values = [
    file("${path.module}/config/istio/istiod-values.yaml")
  ]

}



resource "azurerm_public_ip" "ingress-public-ip-istio" {
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-ingress-pip-istio"
  location            = data.azurerm_resource_group.resource_group_istio.location
  resource_group_name = data.azurerm_resource_group.resource_group_istio.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes =  [tags] }
}


data "azurerm_resource_group" "resource_group_istio" {
  name = var.resource_group_name
}

# CREATE K8S GATEWAY WITH TLS CERTIFICATE
resource "kubernetes_manifest" "istio_gateway" {
  manifest = yamldecode(
    file("${path.module}/config/istio/gateway.yaml")
  )

    depends_on = [
    helm_release.istio_base,
    helm_release.istiod,
    helm_release.istio_ingress
  ]
}


#CREATES K8S SERVICE + DEPLOYMENT
resource "helm_release" "istio_ingress" {
  name       = "istio-ingress-gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = "istio-ingress"

  create_namespace = true
  depends_on       = [helm_release.istiod]

  values = [
    file("${path.module}/config/istio/istio-ingress-values.yaml")
  ]

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

  # Enable prometheus metrics and configure scraping

# set {
#    name  = "metrics.enabled"
#    value = "true"
#    type  = "auto"
#  }



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



  # Send X-Forwarded-For HTTP header to keep the client IP for the apps
  # When used behind front door, it contains the front door backend IP as well
  # The Host header is replaced by the value of X-Forwarded-Host header. When using front door,
  # apps will see the external host instead of the ingress host
#  set {
#    name  = "controller.config.use-forwarded-headers"
#    value = "true"
#    type  = "string"
#  }

#  set {
#    name  = "controller.config.compute-full-forwarded-for"
#    value = "true"
#    type  = "string"
#  }

#  set {
#    name  = "containerSecurityContext.readOnlyRootFilesystem"
#    value = "true"
#    type  = "string"
# }

}



#  set {
#    name  = "controller.automountServiceAccountToken"
#    value = "false"
#    type  = "string"
#  }


  # Set ingress class name so it can be retrieved as an attribute to force dependencies
#  set {
#    name  = "controller.ingressClassResource.name"
#    value = "nginx"
#    type  = "string"

#  }
  # Block access to /metrics endpoint
#  dynamic "set" {
#    for_each = var.block_metrics_endpoint ? [1] : []

#    content {
#      name  = "controller.config.server-snippet"
#      value = <<-EOT
#        location /metrics {
#            deny all;
#        }
#      EOT
#      type  = "string"
#    }
#  }




