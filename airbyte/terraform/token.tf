resource "kubernetes_service" "airbyte-token" {
for_each = toset(var.airbyte_namespaces)

  metadata {
    name      = "airbyte-token"
    namespace = "${each.key}"
  }

  spec {
    port {
      name        = "http"
      port        = 4567
      target_port = 4567
    }
    selector = {
      app : "airbyte-token"
    }
    type       = "ClusterIP"
  }
}

resource "kubernetes_deployment" "airbyte-token" {
for_each = toset(var.airbyte_namespaces)

  metadata {
    name      = "airbyte-token"
    namespace = "${each.key}"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "airbyte-token"
      }
    }

    template {
      metadata {
        labels = {
          app              = "airbyte-token"
          "azure.workload.identity/use" = "true"
        }
      }

      spec {

        service_account_name = "airbyte-admin"
        node_selector = {
          "teacherservices.cloud/node_pool" = "applications"
          "kubernetes.io/os"                = "linux"
        }

        container {
          image = "ghcr.io/dfe-digital/teacher-services-cloud:airbyte-token"
          name  = "airbyte-token"
          security_context {
            run_as_user  = 1000
            run_as_group = 3000
            capabilities {
              drop = ["ALL"]
            }
            allow_privilege_escalation = false
            privileged                 = false
            run_as_non_root            = true
            read_only_root_filesystem  = true
            seccomp_profile {
              type = "RuntimeDefault"
            }
          }

          port {
            container_port = 4567
            name           = "http"
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}
