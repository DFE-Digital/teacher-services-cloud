#K8S WELCOME-APP HTTP ROUTE
resource "kubectl_manifest" "welcome-app-http-route" {
  yaml_body = file("${path.module}/config/gateway-api/welcome-app.yaml")
}