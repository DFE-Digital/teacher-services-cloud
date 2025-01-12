resource "helm_release" "reloader" {
  name       = "reloader"
  namespace  = "monitoring"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  version    = var.reloader_version

  set {
    name  = "reloader.watchGlobally"
    value = "true"
  }

  set {
    name  = "reloader.deployment.resources.limits.memory"
    value = var.reloader_app_mem
  }

  set {
    name  = "reloader.deployment.resources.limits.cpu"
    value = var.reloader_app_cpu
  }

  set {
    name  = "reloader.deployment.resources.requests.memory"
    value = var.reloader_app_mem
  }

  set {
    name  = "reloader.deployment.resources.requests.cpu"
    value = var.reloader_app_cpu
  }
}
