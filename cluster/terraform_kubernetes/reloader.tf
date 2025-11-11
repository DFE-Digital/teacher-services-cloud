# ClusterRole for Reloader
resource "kubernetes_cluster_role" "reloader" {
  metadata {
    name = "reloader-role"
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["list", "get", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch", "update"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["cronjobs", "jobs"]
    verbs      = ["list", "get", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "statefulsets"]
    verbs      = ["list", "get", "update", "patch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["deployments", "daemonsets"]
    verbs      = ["list", "get", "update", "patch"]
  }
}

# ServiceAccount for Reloader
resource "kubernetes_service_account" "reloader" {
  metadata {
    name      = "reloader"
    namespace = kubernetes_namespace.default_list["infra"].metadata[0].name
  }
}

# ClusterRoleBinding for Reloader
resource "kubernetes_cluster_role_binding" "reloader" {
  metadata {
    name = "reloader-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.reloader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.reloader.metadata[0].name
    namespace = kubernetes_service_account.reloader.metadata[0].namespace
  }
}

# Deployment for Reloader
resource "kubernetes_deployment" "reloader" {
  metadata {
    name      = "reloader"
    namespace = kubernetes_namespace.default_list["infra"].metadata[0].name
    labels = {
      app = "reloader"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "reloader"
      }
    }

    template {
      metadata {
        labels = {
          app = "reloader"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.reloader.metadata[0].name

        container {
          name  = "reloader"
          image = "ghcr.io/dfe-digital/teacher-services-cloud:reloader-${var.reloader_version}"

          args = ["--reload-strategy=annotations"]

          resources {
            limits = {
              cpu    = var.reloader_app_cpu
              memory = var.reloader_app_mem
            }
            requests = {
              cpu    = var.reloader_app_cpu
              memory = var.reloader_app_mem
            }
          }

          security_context {
            run_as_user  = 65534 # nobody user
            run_as_group = 65534 # nobody group
            capabilities {
              drop = ["ALL"]
            }
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = true
            seccomp_profile {
              type = "RuntimeDefault"
            }
          }
        }
      }
    }
  }
}
