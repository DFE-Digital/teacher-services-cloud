# WELCOME APP -  CREATE VS TO ROUTE TRAFFIC FROM
resource "kubernetes_manifest" "istio_virtual_service" {
  manifest = yamldecode(
    file("${path.module}/config/istio/virtual-service.yaml")
  )
}