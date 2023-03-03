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
  set {
    name  = "controller.extraArgs.default-ssl-certificate"
    value = "default/cert-secret"
  }
  set {
    name  = "controller.config.proxy-buffer-size"
    value = "8k"
  }
  set {
    name  = "controller.replicaCount"
    value = 20
  }
  set {
    name  = "controller.nodeSelector.kubernetes\\.azure\\.com/agentpool"
    value = "applications"
  }
}
