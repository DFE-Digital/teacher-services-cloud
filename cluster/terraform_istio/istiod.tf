#ISTIOD - HELM CHART - CONTROL PLANE
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  wait            = true
  wait_for_jobs   = true
  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  depends_on = [helm_release.istio_base]
  values = [
    file("${path.module}/config/values/istiod-values.yaml")
  ]

}
