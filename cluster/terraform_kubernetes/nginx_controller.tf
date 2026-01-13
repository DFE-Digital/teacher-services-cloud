resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://helm.nginx.com/stable"
  chart      = "nginx-ingress"
  version    = "2.4.1" # var.ingress_nginx_version

    values = [templatefile("config/nginx-ingress-values.yaml", {
      azure_resource_group = azurerm_public_ip.nginx_ingress_public_ip.resource_group_name
      public_ip_address    = azurerm_public_ip.nginx_ingress_public_ip.ip_address
      ingress_nginx_memory = var.ingress_nginx_memory
      server_snippet       = local.server_snippet
    })]

#  set = [
#    {
#      name  = "controller.logLevel"
#      value = "info"
#      type  = "string"
#    },
#    {
#      name  = "controller.replicaCount"
#      value = "1"
#      type  = "auto"
#    },
#    {
#      name  = "controller.nodeSelector.teacherservices\\.cloud/node_pool"
#      value = "applications"
#      type  = "string"
#    },
#    {
#      name  = "controller.ingressClass.name"
#      value = "nginx-ingress"
#      type  = "string"
#    },
#    {
#      name  = "controller.defaultTLS.secret"
#      value = "default/cert-secret"
#      type  = "string"
#    },
#    {
#      name  = "controller.pod.annotations.prometheus\\.io/port"
#      value = "10254"
#      type  = "string"
#    },
#    {
#      name  = "controller.pod.annotations.prometheus\\.io/scrape"
#      value = "true"
#      type  = "string"
#    },
#    {
#      name  = "controller.pod.annotations.prometheus\\.io/path"
#      value = "/metrics"
#      type  = "string"
#    },
#    {
#      name  = "controller.pod.annotations.logit\\.io/send"
#      value = "true"
#      type  = "string"
#    },
#    {
#      name  = "controller.pod.annotations.fluentbit\\.io/exclude"
#      value = "true"
#      type  = "string"
#    },
#    {
#      name  = "controller.service.httpPort.enable"
#      value = "false"
#      type  = "auto"
#    },
#    {
#      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
#      value = azurerm_public_ip.ingress-public-ip.resource_group_name
#      type  = "string"
#    },
#    {
#      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-ipv4"
#      value = azurerm_public_ip.ingress-public-ip.ip_address
#      type  = "string"
#    },
#    {
#      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
#      value = "/healthz"
#      type  = "string"
#    },
#    {
#      name  = "controller.service.externalTrafficPolicy"
#      value = "Local"
#      type  = "string"
#    },
#    {
#      name  = "controller.config.entries.client-max-body-size"
#      value = "50m"
#      type  = "string"
#    },
#    {
#      name  = "controller.config.entries.proxy-buffer-size"
#      value = "24k"
#      type  = "string"
#    },
#    {
#      name  = "controller.config.entries.proxy-busy-buffers-size"
#      value = "24k"
#      type  = "string"
#    },
#    {
#      name  = "controller.config.entries.keepalive"
#      value = "120"
#      type  = "string"
#    },
#    {
#      name  = "controller.config.entries.use-forwarded-headers"
#      value = "true"
#      type  = "string"
#    },
#    {
#      name  = "controller.config.entries.compute-full-forwarded-for"
#      value = "true"
#      type  = "string"
#    },
#    {
#      name  = "controller.config.server-snippet"
#      value = local.server_snippet
#      type  = "string"
#    },
#    {
#      name  = "controller.resources.limits.cpu"
#      value = "500m"
#      type  = "string"
#    },
#    {
#      name  = "controller.resources.limits.memory"
#      value = var.ingress_nginx_memory
#      type  = "string"
#    },
#
#    {
#      name  = "controller.podSecurityContext.allowPrivilegeEscalation"
#      value = "false"
#      type  = "auto"
#    },
#
#    {
#      name  = "controller.securityContext.runAsNonRoot"
#      value = "true"
#      type  = "auto"
#    },
#    {
#      name  = "controller.securityContext.allowPrivilegeEscalation"
#      value = "false"
#      type  = "auto"
#    },
#    {
#      name  = "controller.securityContext.runAsNonRoot"
#      value = "true"
#      type  = "auto"
#    },
#    {
#      name  = "controller.prometheus.create"
#      value = "true"
#      type  = "auto"
#    },
#    {
#      name  = "controller.prometheus.port"
#      value = "10254"
#      type  = "string"
#    },
#  ]
}

resource "azurerm_public_ip" "nginx_ingress_public_ip" {
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-nginx-ingress-pip"
  location            = data.azurerm_resource_group.resource_group.location
  resource_group_name = data.azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}
