

resource "kubernetes_service_account" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = var.kube_state_metrics_version
    }
  }
}


resource "kubernetes_cluster_role" "kube_state_metrics" {
  metadata {
    name = "kube-state-metrics"
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = var.kube_state_metrics_version
    }
  }
  rule {
    api_groups = ["", "apps", "batch", "networking.k8s.io", "policy", "autoscaling", "certificates.k8s.io", "coordination.k8s.io", "storage.k8s.io", "admissionregistration.k8s.io"]
    resources  = ["pods", "replicasets", "cronjobs", "ingresses", "poddisruptionbudgets", "networkpolicies", "storageclasses", "certificatesigningrequests", "leases", "horizontalpodautoscalers", "configmaps", "secrets", "nodes", "services", "resourcequotas", "replicationcontrollers", "limitranges", "persistentvolumeclaims", "persistentvolumes", "namespaces", "endpoints", "deployments", "statefulsets", "daemonsets", "volumeattachments", "mutatingwebhookconfigurations", "validatingwebhookconfigurations", "jobs"]
    verbs      = ["get", "list", "watch"]
  }

}
resource "kubernetes_cluster_role_binding" "kube_state_metrics" {
  metadata {
    name = "kube-state-metrics"
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = var.kube_state_metrics_version
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.kube_state_metrics.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }
}

resource "kubernetes_deployment" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = var.kube_state_metrics_version
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "kube-state-metrics"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/component" = "exporter"
          "app.kubernetes.io/name"      = "kube-state-metrics"
          "app.kubernetes.io/version"   = var.kube_state_metrics_version
        }
      }

      spec {
        automount_service_account_token = true
        service_account_name            = kubernetes_service_account.kube_state_metrics.metadata[0].name

        container {
          name  = "kube-state-metrics"
          image = "registry.k8s.io/kube-state-metrics/kube-state-metrics:v${var.kube_state_metrics_version}"
          port {
            name           = "http-metrics"
            container_port = 8080
          }
          port {
            name           = "telemetry"
            container_port = 8081
          }

          # Add readiness/liveness probes, resources, etc
          readiness_probe {
            http_get {
              path = "/"
              port = 8081
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
          }
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "256Mi"
            }
          }
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "kube_state_metrics" {
  metadata {
    name      = "kube-state-metrics"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name

    labels = {
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/name"      = "kube-state-metrics"
      "app.kubernetes.io/version"   = var.kube_state_metrics_version
    }
  }

  spec {
    cluster_ip = "None"

    selector = {
      "app.kubernetes.io/name" = "kube-state-metrics"
    }

    port {
      name        = "http-metrics"
      port        = 8080
      target_port = "http-metrics"
    }

    port {
      name        = "telemetry"
      port        = 8081
      target_port = "telemetry"
    }
  }
}
