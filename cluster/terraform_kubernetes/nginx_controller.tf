resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://helm.nginx.com/stable"
  chart      = "nginx-ingress"
  version    = "2.4.1" # var.ingress_nginx_version

  # The first part of the name with simple dots is the keys path in the values.yml file.
  # The last part is the final key (double-escape dots if the key contains dots).
  # The corresponding value is in the "value" argument.
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
    type  = "string"
  }
  # Resource group of the ingress public IP.
  # The cluster managed identity must have Network Contributor role on the resource group.
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = azurerm_public_ip.nginx_ingress_public_ip.resource_group_name
    type  = "string"
  }
  # Ingress IP.
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-ipv4"
    value = azurerm_public_ip.nginx_ingress_public_ip.ip_address
    type  = "string"
  }
  # Route requests from the load balancer to the ingress pods on the same node instead of adding one more hop.
  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
    type  = "string"
  }
  set {
    name  = "controller.defaultTLS.secret"
    value = "default/cert-secret"
    type  = "string"
  }
  # Disable HTTP port 80 on the Azure load balancer.
  set {
    name  = "controller.service.httpPort.enable"
    value = "false"
    type  = "auto"
  }
  # Allow POST requests with large body. Prevent error 413: Request entity too large.
  set {
    name  = "controller.config.entries.client-max-body-size"
    value = "50m"
    type  = "string"
  }
  # Sets the size of the buffer used for reading the first part of the response received from the proxied server.
  set {
    name  = "controller.config.entries.proxy-buffer-size"
    value = "24k"
    type  = "string"
  }
  # This ConfigMap setting sets the time, in seconds, during which a keep-alive client connection will stay open on the server side.
  set {
    name  = "controller.config.entries.keepalive"
    value = "120"
    type  = "auto"
  }
  set {
    name  = "controller.config.entries.use-forwarded-headers"
    value = "true"
    type  = "string"
  }
  set {
    name  = "controller.config.entries.compute-full-forwarded-for"
    value = "true"
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

  set {
    name  = "controller.resources.limits.cpu"
    value = "500m"
    type  = "string"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = var.ingress_nginx_memory
    type  = "string"
  }

  # Enable prometheus metrics and configure scraping.
  set {
    name  = "prometheus.create"
    value = "true"
    type  = "auto"
  }
  set {
    name  = "prometheus.port"
    value = "10254"
    type  = "string"
  }
  set {
    name  = "controller.pod.annotations.prometheus\\.io/port"
    value = "10254"
    type  = "string"
  }
  set {
    name  = "controller.pod.annotations.prometheus\\.io/scrape"
    value = "true"
    type  = "auto"
  }
  set {
    name  = "controller.pod.annotations.prometheus\\.io/path"
    value = "/metrics"
    type  = "string"
  }
  # Enable shipping logs to Logit.io.
  set {
    name  = "controller.pod.annotations.logit\\.io/send"
    value = "true"
    type  = "string"
  }
  # Disable shipping logs to Log analytics via Container insights.
  set {
    name  = "controller.pod.annotations.fluentbit\\.io/exclude"
    value = "true"
    type  = "string"
  }

  # Set ingress class name so it can be retrieved as an attribute to force dependencies.
  set {
    name  = "controller.ingressClass.name"
    value = "nginx-ingress"
    type  = "string"
  }
  # Block access to /metrics endpoint.
  dynamic "set" {
    for_each = var.block_metrics_endpoint ? [1] : []

    content {
      name  = "controller.config.entries.server-snippets"
      value = <<-EOT
        location /metrics {
            deny all;
        }
      EOT
      type  = "string"
    }
  }

  set {
    name  = "controller.podSecurityContext.runAsUser"
    value = "1000"
    type  = "auto"
  }
  set {
    name  = "controller.podSecurityContext.runAsGroup"
    value = "3000"
    type  = "auto"
  }
  set {
    name  = "controller.securityContext.capabilities.drop[0]"
    value = "ALL"
    type  = "string"
  }
  // By default, NET_BIND_SERVICE is added to the deployment by the Helm chart, even if we do not explicitly set it.

  set {
    name  = "controller.securityContext.allowPrivilegeEscalation"
    value = "false"
    type  = "string"
  }
  set {
    name  = "controller.securityContext.privileged"
    value = "false"
    type  = "string"
  }
  set {
    name  = "controller.securityContext.runAsNonRoot"
    value = "true"
    type  = "string"
  }
  set {
    name  = "controller.securityContext.readOnlyRootFilesystem"
    value = "true"
    type  = "string"
  }
  set {
    name  = "controller.securityContext.seccompProfile.type"
    value = "RuntimeDefault"
    type  = "string"
  }
}

resource "azurerm_public_ip" "nginx_ingress_public_ip" {
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-ingress-pip"
  location            = data.azurerm_resource_group.resource_group.location
  resource_group_name = data.azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}
