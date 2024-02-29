data "azurerm_key_vault_secret" "grafana_admin_user" {
  name         = "GRAFANA-ADMIN-USER"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_key_vault_secret" "grafana_admin_password" {
  name         = "GRAFANA-ADMIN-PASSWORD"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}


resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "datasources.yaml" = file("${path.module}/config/prometheus/datasources.yaml")
  }
}


resource "kubernetes_deployment" "grafana_deployment" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        container {
          name  = "grafana"
          image = "grafana/grafana:${var.grafana_version}"
          port {
            container_port = 3000
          }
          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = data.azurerm_key_vault_secret.grafana_admin_user.value
          }
          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = data.azurerm_key_vault_secret.grafana_admin_password.value
          }
          resources {
            limits = {
              cpu    = "1"
              memory = var.grafana_limit_mem
            }
            requests = {
              cpu    = var.grafana_app_cpu
              memory = var.grafana_app_mem
            }
          }
          volume_mount {
            name       = "grafana-storage"
            mount_path = "/var/lib/grafana"
          }
          volume_mount {
            name       = "grafana-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }
        }
        volume {
          name = "grafana-datasources"
          config_map {
            name = kubernetes_config_map.grafana_datasources.metadata[0].name
          }
        }
        volume {
          name = "grafana-storage"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana_service" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_deployment.grafana_deployment.spec[0].template[0].metadata[0].labels["app"]
    }

    port {
      port        = 3000
      target_port = 3000
    }
  }
}
