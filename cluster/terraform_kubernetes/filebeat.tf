data "azurerm_key_vault_secret" "beats_url" {
  name         = "BEATS-URL"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "kubernetes_service_account" "filebeat" {
  metadata {
    name      = "filebeat"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      "name" = "filebeat"
    }
  }
}

resource "kubernetes_cluster_role" "filebeat" {
  metadata {
    name = "filebeat"
    labels = {
      "name" = "filebeat"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }

}

resource "kubernetes_cluster_role_binding" "filebeat" {
  metadata {
    name = "filebeat"
    labels = {
      "name" = "filebeat"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.filebeat.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "filebeat"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }
}

resource "kubernetes_config_map" "filebeat" {

  metadata {
    name      = "filebeat-config-${local.config_map_hash}"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "filebeat.yml" = local.config_map_data
  }

}

locals {
  config_map_data = templatefile("${path.module}/config/filebeat/filebeat.yml.tmpl", local.filebeats_template_variable_map)
  config_map_hash = sha1(local.config_map_data)
}

resource "kubernetes_daemonset" "filebeat" {

  metadata {
    name      = "filebeat"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      app = "filebeat"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "filebeat"
      }
    }


    template {
      metadata {
        labels = {
          app = "filebeat"
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
          image = "docker.elastic.co/beats/filebeat-oss:${var.filebeat_version}"
          name  = "filebeat"

          args = [
            "-c",
            "filebeat.yml",
            "-e",
          ]

          security_context {
            run_as_user = 0
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
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
            name         = kubernetes_config_map.filebeat.metadata[0].name
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
            path = "/var/lib/filebeat-data"
            type = "DirectoryOrCreate"
          }
        }

      }
    }
  }
}

#
# Clone definition
#

resource "kubernetes_service_account" "filebeat_clone" {
  count = var.clone_cluster ? 1 : 0
  provider = kubernetes.clone
  metadata {
    name      = "filebeat"
    namespace = kubernetes_namespace.default_list_clone["monitoring"].metadata[0].name
    labels = {
      "name" = "filebeat"
    }
  }
}

resource "kubernetes_cluster_role" "filebeat_clone" {
  count = var.clone_cluster ? 1 : 0
  provider = kubernetes.clone
  metadata {
    name = "filebeat"
    labels = {
      "name" = "filebeat"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }

}

resource "kubernetes_cluster_role_binding" "filebeat_clone" {
  count = var.clone_cluster ? 1 : 0
  provider = kubernetes.clone
  metadata {
    name = "filebeat"
    labels = {
      "name" = "filebeat"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.filebeat_clone[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "filebeat"
    namespace = kubernetes_namespace.default_list_clone["monitoring"].metadata[0].name
  }
}

resource "kubernetes_config_map" "filebeat_clone" {
  count = var.clone_cluster ? 1 : 0
  provider = kubernetes.clone

  metadata {
    name      = "filebeat-config-${local.config_map_hash}"
    namespace = kubernetes_namespace.default_list_clone["monitoring"].metadata[0].name
  }

  data = {
    "filebeat.yml" = local.config_map_data
  }

}

resource "kubernetes_daemonset" "filebeat_clone" {
  count = var.clone_cluster ? 1 : 0
  provider = kubernetes.clone

  metadata {
    name      = "filebeat"
    namespace = kubernetes_namespace.default_list_clone["monitoring"].metadata[0].name
    labels = {
      app = "filebeat"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "filebeat"
      }
    }


    template {
      metadata {
        labels = {
          app = "filebeat"
        }
      }

      spec {
        service_account_name             = kubernetes_service_account.filebeat_clone[0].metadata[0].name
        termination_grace_period_seconds = 30

        node_selector = {
          "teacherservices.cloud/node_pool" = "applications"
          "kubernetes.io/os"                = "linux"
        }

        container {
          image = "docker.elastic.co/beats/filebeat-oss:${var.filebeat_version}"
          name  = "filebeat"

          args = [
            "-c",
            "filebeat.yml",
            "-e",
          ]

          security_context {
            run_as_user = 0
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
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
            name         = kubernetes_config_map.filebeat_clone[0].metadata[0].name
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
            path = "/var/lib/filebeat-data"
            type = "DirectoryOrCreate"
          }
        }

      }
    }
  }
}
