data "azurerm_key_vault_secret" "slack_secret" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
  name         = "SLACK-SECRET"
}
resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "alertmanager-config"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "config.yml" = local.alertmanager_config_content
  }
}

resource "kubernetes_config_map" "alertmanager_templates" {
  metadata {
    name      = "alertmanager-templates"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = local.alertmanager_templates
}

resource "kubernetes_deployment" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "alertmanager"
      }
    }

    template {
      metadata {
        labels = {
          app = "alertmanager"
        }
      }

      spec {
        container {
          image = "prom/alertmanager:${var.alertmanager_image_version}"
          name  = "alertmanager"

          args = [
            "--config.file=/etc/alertmanager/config.yml",
            "--storage.path=/alertmanager",
          ]


          port {
            container_port = 9093
          }

          resources {
            limits = {
              cpu    = 1
              memory = var.alertmanager_app_mem
            }

            requests = {
              cpu    = var.alertmanager_app_cpu
              memory = var.alertmanager_app_mem
            }
          }

          volume_mount {
            mount_path = "/etc/alertmanager"
            name       = "config-volume"
          }

          volume_mount {
            mount_path = "/etc/alertmanager-templates"
            name       = "templates-volume"
          }

          volume_mount {
            mount_path = "/alertmanager"
            name       = "alertmanager"
          }
        }

        volume {
          name = "config-volume"

          config_map {
            name = kubernetes_config_map.alertmanager_config.metadata[0].name
          }
        }

        volume {
          name = "templates-volume"

          config_map {
            name = kubernetes_config_map.alertmanager_templates.metadata[0].name
          }
        }

        volume {
          name = "alertmanager"
          empty_dir {}
        }
      }
    }
  }
}

# Service for AlertManager
resource "kubernetes_service" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    annotations = {
      "prometheus.io/port"   = "9093"
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    selector = {
      app = "alertmanager"
    }

    port {
      port        = 9093
      target_port = 9093
    }

    type = "NodePort"
  }
}
