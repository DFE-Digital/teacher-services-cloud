resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_version

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
  # Resource group of the ingress public IP
  # The cluster managed identity must have Network Contributor role on the resource group
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = azurerm_public_ip.ingress-public-ip.resource_group_name
    type  = "string"
  }
  # Ingress IP
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-ipv4"
    value = azurerm_public_ip.ingress-public-ip.ip_address
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
    value = "50m"
    type  = "string"
  }
  # Sets the size of the buffer used for reading the first part of the response received from the proxied server.
  # Needs to be larger than the response header or nginx will return an error for the request
  # https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#proxy-buffer-size
  set {
    name  = "controller.config.proxy-buffer-size"
    value = "24k"
    type  = "string"
  }
  # This ConfigMap setting sets the time, in seconds, during which a keep-alive client connection will stay open on the server side
  set {
    name  = "controller.config.keep-alive"
    value = "120"
    type  = "auto"
  }
  # This ConfigMap setting defines a timeout for reading client request header, in seconds
  set {
    name  = "controller.config.client-header-timeout"
    value = "120"
    type  = "auto"
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
    name  = "controller.resources.limits.cpu"
    value = "500m"
    type  = "string"
  }
  set {
    name  = "controller.resources.limits.memory"
    value = "512Mi"
    type  = "string"
  }

  # Annotations to enable scraping for ingress controller
  # where podAnnotations is the top level property, port is ingress controller port for metrics,
  # path is default path for metrics used throughout, enabled is true if scraping is desired
  set {
    name  = "controller.podAnnotations.prometheus\\.io/scrape"
    value = "true"
    type  = "string"
  }
  set {
    name  = "controller.podAnnotations.prometheus\\.io/path"
    value = "/metrics"
    type  = "string"
  }
  set {
    name  = "controller.podAnnotations.prometheus\\.io/port"
    value = "10254"
    type  = "string"
  }
  # Enable shipping logs to Logit.io
  set {
    name  = "controller.podAnnotations.logit\\.io/send"
    value = "true"
    type  = "string"
  }
  # Disable shipping logs to Log analytics via Container insights
  set {
    name  = "controller.podAnnotations.fluentbit\\.io/exclude"
    value = "true"
    type  = "string"
  }

  # Set ingress class name so it can be retrieved as an attribute to force dependencies
  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
    type  = "string"
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
    # Exclude the load balancer IP to force clone to use dynamic Public IP for load balancer ingress
    for_each = [
      for s in helm_release.ingress-nginx.set : s
      if s.name != "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-ipv4"
      && s.name != "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    ]

    content {
      name  = set.value["name"]
      value = set.value["value"]
      type  = set.value["type"]
    }
  }
}

resource "azurerm_public_ip" "ingress-public-ip" {
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-ingress-pip"
  location            = data.azurerm_resource_group.resource_group.location
  resource_group_name = data.azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}

data "azurerm_resource_group" "resource_group" {
  name = var.resource_group_name
}
