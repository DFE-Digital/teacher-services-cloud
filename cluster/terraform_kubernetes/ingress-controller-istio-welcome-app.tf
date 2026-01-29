# WELCOME APP -  CREATE VS TO ROUTE TRAFFIC FROM
resource "kubernetes_manifest" "istio_virtual_service" {
  manifest = yamldecode(
    file("${path.module}/config/istio/virtual-service.yaml")
  )
}

# CREATE K8S GATEWAY WITH TLS CERTIFICATE
resource "kubernetes_manifest" "istio_gateway" {
  manifest = yamldecode(
    file("${path.module}/config/istio/gateway.yaml")
  )

}
