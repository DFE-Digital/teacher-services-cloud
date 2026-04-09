locals {
  welcome_app_middleware_yaml = templatefile("${path.module}/config/gateway-api/welcome-app-middleware.yaml.tftpl", {
    route_namespace    = "infra"
    rate_limit_name    = "welcome-app-ratelimit"
    rate_limit_average = 60
    rate_limit_period  = "1m"
    rate_limit_burst   = 20
  })

  welcome_app_httproute_yaml = templatefile("${path.module}/config/gateway-api/welcome-app-httproute.yaml.tftpl", {
    route_name           = "welcome-app-route"
    route_namespace      = "infra"
    gateway_name         = "development-gateway-api"
    gateway_namespace    = "gateway-api"
    gateway_section_name = "websecure"
    hostname             = "welcomeapp-gatewayapi.cluster3.development.teacherservices.cloud"
    backend_name         = "welcome-app"
    backend_port         = 80
    rate_limit_name      = "welcome-app-ratelimit"
  })
}

resource "kubernetes_manifest" "welcome_app_middleware" {
  manifest = yamldecode(local.welcome_app_middleware_yaml)
}

resource "kubernetes_manifest" "welcome_app_httproute" {
  manifest   = yamldecode(local.welcome_app_httproute_yaml)
  depends_on = [kubernetes_manifest.welcome_app_middleware]
}