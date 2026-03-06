data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml"
}

resource "kubectl_manifest" "gateway_api_crds" {
  yaml_body = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway" {
  yaml_body = file("${path.module}/config/values/gateway-class.yaml")
}