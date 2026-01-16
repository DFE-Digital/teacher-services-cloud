resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_version
  namespace  = "istio-system"
't meet the specifications of the schema(s) in the following chart(s):
│ gateway:
│ - (root): Additional property metrics is not allowed
  create_namespace = true
}




resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  depends_on = [helm_release.istio_base]
}





resource "azurerm_public_ip" "ingress-public-ip-istio" {
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-ingress-pip-istio"
  location            = data.azurerm_resource_group.resource_group_istio.location
  resource_group_name = data.azurerm_resource_group.resource_group_istio.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}


data "azurerm_resource_group" "resource_group_istio" {
  name = var.resource_group_name
}



resource "helm_release" "istio_ingress" {
  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = "istio-ingress"

  create_namespace = true
  depends_on       = [helm_release.istiod]


  # Ingress IP
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = data.azurerm_resource_group.resource_group_istio.name
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-ip-name"
    value = azurerm_public_ip.ingress-public-ip-istio.name
  }

  # Route requests from the load balancer to the ingress pods on the same node instead of adding one more hop to the node with most pods.
  # This preserves the client IP and removes a hop. Itingress-public-ip potentially creates a traffic imbalance but this should have no effect for us
  # as we should have many well distributed ingress pods.
  set {
    name  = "service.externalTrafficPolicy"
    value = "Local"
    type  = "string"
  }
  #
  #NOT IN ISTEO! - CREATE A K8S SECRET  
  #set {
  #  name  = "service.default-ssl-certificate"
  #  value = "default/cert-secret"
  #  type  = "string"
  #}


  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz/ready"
    type  = "string"
  }



  # Disable HTTP port 80 on the Azure load balancer
#  set {ingress-public-ip
#    name  = "controller.service.enableHttp"
#    value = "false"
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

  set {
    name  = "replicaCount"
    value = 1
    type  = "auto"
  }
  set {
    name  = "nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }

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



  # Resource requests and limits for the ingress controller pods
  set {
    name  = "resources.limits.cpu"
    value = "500m"
    type  = "string"
  }
  set {
    name  = "resources.limits.memory"
    value = var.ingress_nginx_memory
    type  = "string"
  }

  # Enable prometheus metrics and configure scraping

 set {
    name  = "metrics.enabled"
    value = "true"
    type  = "auto"
  }

  set {
    name  = "podAnnotations.prometheus\\.io/scrape"
    value = "true"
    type  = "string"
  }
  set {
    name  = "podAnnotations.prometheus\\.io/path"
    value = "/metrics"
    type  = "string"
  }
  set {
    name  = "podAnnotations.prometheus\\.io/port"
    value = "10254"
    type  = "string"
  }

  # Enable shipping logs to Logit.io
  set {
    name  = "podAnnotations.logit\\.io/send"
    value = "true"
    type  = "string"
  }
  # Disable shipping logs to Log analytics via Container insights
  set {
    name  = "podAnnotations.fluentbit\\.io/exclude"
    value = "true"
    type  = "string"
  }

# Security context settings
  set {
    name  = "securityContext.runAsUser"
    value = "1000"
    type  = "auto"
  }

  set {
    name  = "securityContext.runAsGroup"
    value = "3000"
    type  = "auto"
  }

  set {
    name  = "securityContext.allowPrivilegeEscalation"
    value = "false"
    type  = "string"
  }
  set {
    name  = "securityContext.privileged"
    value = "false"
    type  = "string"
  }

  set {
    name  = "securityContext.capabilities.drop[0]"
    value = "ALL"
    type  = "string"
  }
  // By default, NET_BIND_SERVICE is added to the deployment by the Helm chart, even if we do not explicitly set it.

  set {
    name  = "securityContext.seccompProfile.type"
    value = "RuntimeDefault"
    type  = "string"
  }

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
