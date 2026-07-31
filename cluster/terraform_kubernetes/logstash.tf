data "azurerm_key_vault_secret" "splunk_events_url" {
  name         = "SPLUNK-URL-EVENTS"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_key_vault_secret" "splunk_events_token" {
  name         = "SPLUNK-EVENTS-TOKEN"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "kubernetes_service_account" "logstash" {
  count = var.enable_splunk_logging ? 1 : 0
  metadata {
    name      = "logstash"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      "name" = "logstash"
    }
  }
}

resource "kubernetes_config_map" "logstash_conf" {
  count = var.enable_splunk_logging ? 1 : 0
  metadata {
    name      = "logstash-config"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "logstash.yml" = local.ls_config_map_data
  }

}

resource "kubernetes_config_map" "logstash_pipeline" {
  count = var.enable_splunk_logging ? 1 : 0

  metadata {
    name      = "logstash-pipeline"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "pipeline.conf" = local.ls_pipeline_config_map
  }

}

locals {
  ls_config_map_data = file("${path.module}/config/logstash/logstash.yml.tmpl")
  ls_pipeline_config_map = templatefile("${path.module}/config/logstash/pipeline.conf.tmpl", local.logstash_template_variable_map)
#   ls_config_map_hash = sha1(local.ls_config_map_data)
}

resource "kubernetes_deployment" "logstash" {
  count = var.enable_splunk_logging ? 1 : 0
  metadata {
    name      = "logstash"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      app = "logstash"
    }
  }

  spec {
    replicas = var.logstash_replica_count
    selector {
      match_labels = {
        app = "logstash"
      }
    }

    template {
      metadata {
        labels = {
          app = "logstash"
        }
      }

      spec {
        service_account_name = "logstash"

        container {
          name  = "logstash"
          image = "${var.tsc_package_repo}:${var.logstash_image}-${var.logstash_version}"
          security_context {
              run_as_user  = 1000
              run_as_group = 1000
              capabilities {
                drop = ["ALL"]
              }
              allow_privilege_escalation = false
              privileged                 = false
              run_as_non_root            = true
              read_only_root_filesystem  = false
              seccomp_profile {
                type = "RuntimeDefault"
              }
          }    

          resources {
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }

          env {
            name  = "LS_JAVA_OPTS"
            value = "-Xms512m -Xmx512m"
          }

          # Config mounts
          volume_mount {
            name       = "logstash-config"
            mount_path = "/usr/share/logstash/config/logstash.yml"
            sub_path   = "logstash.yml"
          }

          volume_mount {
            name       = "logstash-pipeline"
            mount_path = "/usr/share/logstash/pipeline/logstash.conf"
            sub_path   = "pipeline.conf"
          }

          # 🔑 Kubernetes container logs
          volume_mount {
            name       = "varlogcontainers"
            mount_path = "/var/log/containers"
            read_only  = true
          }

          volume_mount {
            name       = "varlogpods"
            mount_path = "/var/log/pods"
            read_only  = true
          }

          volume_mount {
            name       = "log-data"
            mount_path = "/usr/share/logstash/log-data"
          }
        }

        # Volumes
        volume {
          name = "logstash-config"

          config_map {
            name = "logstash-config"
          }
        }

        volume {
          name = "logstash-pipeline"

          config_map {
            name = "logstash-pipeline"
          }
        }

        # 🔑 Required for Kubernetes logs
        volume {
          name = "varlogcontainers"

          host_path {
            path = "/var/log/containers"
          }
        }

        volume {
          name = "log-data"
          host_path {
            path = "/var/lib/log-data"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "varlogpods"

          host_path {
            path = "/var/log/pods"
          }
        }

        toleration {
          operator = "Exists"
        }
      }
    }
  }
}

resource "kubernetes_service" "logstash" {
  count = var.enable_splunk_logging ? 1 : 0
  metadata {
    name      = "logstash"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      app = "logstash"
    }
  }

  spec {
    selector = {
      app = "logstash"
    }

    port {
      name        = "beats"
      port        = 5044        # Service port
      target_port = 5044        # Container port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
