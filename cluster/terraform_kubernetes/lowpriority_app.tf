resource "kubernetes_priority_class_v1" "lowpriority" {
  count = var.enable_lowpriority_app ? 1 : 0

  metadata {
    name = "lowpriority"
  }

  value = -1
}

resource "kubernetes_deployment" "lowpriority_app" {
  count = var.enable_lowpriority_app ? 1 : 0

  metadata {
    name      = local.lowpriority_app_name
    namespace = local.lowpriority_app_namespace
  }
  spec {
    replicas = var.lowpriority_app_replicas
    selector {
      match_labels = {
        app = local.lowpriority_app_name
      }
    }
    template {
      metadata {
        labels = {
          app = local.lowpriority_app_name
        }
      }
      spec {
        node_selector = {
          "teacherservices.cloud/node_pool" = "applications"
          "kubernetes.io/os"                = "linux"
        }
        priority_class_name = "lowpriority"
        container {
          name  = local.lowpriority_app_name
          image = "k8s.gcr.io/pause"

          resources {
            requests = {
              cpu    = var.lowpriority_app_cpu
              memory = var.lowpriority_app_mem
            }
            limits = {
              cpu    = 1
              memory = var.lowpriority_app_mem
            }
          }
        }
      }
    }
  }
}
