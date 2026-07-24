resource "kubernetes_config_map" "filebeat_splunk" {
  count = var.enable_splunk_logging ? 1 : 0

  metadata {
    name      = "filebeat-splunk"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "filebeat.yml" = local.fb_splunk_config_map_data
  }

}

locals {
  fb_splunk_config_map_data = file("${path.module}/config/filebeat/filebeat-splunk.yml.tmpl")
#   ls_config_map_hash = sha1(local.ls_config_map_data)
}

resource "kubernetes_daemonset" "filebeat_splunk" {
  count = var.enable_splunk_logging ? 1 : 0

  metadata {
    name      = "filebeat-splunk"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      app = "filebeat"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "filebeat-splunk"
      }
    }


    template {
      metadata {
        labels = {
          app = "filebeat-splunk"
        }
        annotations = {
          "fluentbit.io/exclude" = "true"
        }
      }

      spec {
        service_account_name             = kubernetes_service_account.filebeat.metadata[0].name
        termination_grace_period_seconds = 30

        node_selector = {
          "teacherservices.cloud/node_pool" = "applications"
          "kubernetes.io/os"                = "linux"
        }

        container {
          image = "${var.tsc_package_repo}:${var.filebeat_image}-${var.filebeat_version}"
          name  = "filebeat-splunk"

          args = [
            "-c",
            "filebeat.yml",
            "-e",
          ]

          security_context {
            run_as_user = 0


            capabilities {
              drop = ["ALL"]
            }
            allow_privilege_escalation = false
            privileged                 = false
            run_as_non_root            = false
            read_only_root_filesystem  = true
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "300Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "100Mi"
            }
          }

          volume_mount {
            mount_path = "/usr/share/filebeat/filebeat.yml"
            name       = "filebeat-config"
            read_only  = "true"
            sub_path   = "filebeat.yml"
          }

          volume_mount {
            mount_path = "/usr/share/filebeat/data"
            name       = "data"
          }

          volume_mount {
            mount_path = "/var/log"
            name       = "varlog"
            read_only  = "true"
          }

        }

        volume {
          name = "filebeat-config"
          config_map {
            name         = kubernetes_config_map.filebeat_splunk[0].metadata[0].name
            default_mode = "0644"
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "data"
          host_path {
            path = "/var/lib/filebeat-splunk-data"
            type = "DirectoryOrCreate"
          }
        }

      }
    }
  }
}