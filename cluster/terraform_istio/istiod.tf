#ISTIOD - HELM CHART - CONTROL PLANE
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  depends_on = [helm_release.istio_base]
  values = [
    file("${path.module}/config/values/istiod-values.yaml")
  ]

}
