resource "azurerm_storage_account" "thanos" {

  name                            = "${var.resource_prefix}${local.cluster_sa_name}thanossa"
  location                        = data.azurerm_resource_group.resource_group.location
  resource_group_name             = data.azurerm_resource_group.resource_group.name
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  allow_nested_items_to_be_public = false

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_storage_container" "metrics" {

  name                  = "metrics"
  storage_account_name  = azurerm_storage_account.thanos.name
  container_access_type = "private"
}

resource "kubernetes_secret" "thanos" {

  metadata {
    name      = "thanos-objstore-config"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "thanos.yaml"       = templatefile("${path.module}/config/prometheus/thanos.yml.tmpl", local.template_variable_map)
    "object-store.yaml" = templatefile("${path.module}/config/prometheus/thanos.yml.tmpl", local.template_variable_map)
  }
}

resource "kubernetes_service" "thanos-store-gateway" {

  metadata {
    name      = "thanos-store-gateway"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  spec {
    port {
      name        = "grpc"
      port        = 10901
      target_port = "grpc"
    }
    selector = {
      thanos-store-api : "true"
    }
    type       = "ClusterIP"
    cluster_ip = "None"
  }
}

resource "kubernetes_deployment" "thanos-querier" {

  metadata {
    name      = "thanos-querier"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "thanos-querier"
      }
    }

    template {
      metadata {
        labels = {
          app = "thanos-querier"
          # thanos-store-api = true
        }
      }

      spec {

        container {
          image = "${var.tsc_package_repo}:${var.thanos_image}-${var.thanos_version}"
          name  = "thanos-querier"

          security_context {
            run_as_user  = 1001
            run_as_group = 1001
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

          args = [
            "query",
            "--log.level=info",
            "--query.replica-label=replica",
            "--endpoint=dnssrv+_grpc._tcp.thanos-store-gateway.monitoring.svc.cluster.local",
          ]

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = "http"
            }
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = "http"
            }
          }

          port {
            container_port = 10901
            name           = "grpc"
          }

          port {
            container_port = 10902
            name           = "http"
          }

          resources {
            limits = {
              cpu    = 1
              memory = var.thanos_querier_mem
            }
            requests = {
              cpu    = var.thanos_app_cpu
              memory = var.thanos_querier_mem
            }
          }
        }
      }
    }
  }
}



resource "kubernetes_service" "thanos-querier" {

  metadata {
    name      = "thanos-querier"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      app = "thanos-querier"
    }
  }

  spec {
    port {
      name        = "http"
      port        = 9090
      target_port = "http"
      protocol    = "TCP"
    }
    selector = {
      app = "thanos-querier"
    }
  }
}

resource "kubernetes_deployment" "thanos-store-gateway" {

  metadata {
    name      = "thanos-store-gateway"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "thanos-store-gateway"
      }
    }

    template {
      metadata {
        labels = {
          app              = "thanos-store-gateway"
          thanos-store-api = true
        }
      }

      spec {

        container {
          image = "${var.tsc_package_repo}:${var.thanos_image}-${var.thanos_version}"
          name  = "thanos-store-gateway"
          security_context {
            run_as_user  = 1001
            run_as_group = 1001
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

          args = [
            "store",
            "--log.level=info",
            "--data-dir=/data",
            "--objstore.config-file=/config/thanos.yaml",
            "--index-cache-size=500MB",
            "--chunk-pool-size=500MB",
          ]

          port {
            container_port = 10901
            name           = "grpc"
          }

          port {
            container_port = 10902
            name           = "http"
          }

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = "http"
            }
            failure_threshold = 10
            period_seconds    = 10
            timeout_seconds   = 5
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = "http"
            }
          }

          resources {
            limits = {
              cpu    = 1
              memory = var.thanos_store_mem
            }
            requests = {
              cpu    = var.thanos_app_cpu
              memory = var.thanos_store_mem
            }
          }

          volume_mount {
            mount_path = "/config/"
            name       = "thanos-config-volume"
            read_only  = true
          }

          volume_mount {
            mount_path = "/data" # Mounting the /data directory to a writable volume
            name       = "thanos-data-volume"
          }
        }

        volume {
          name = "thanos-config-volume"
          secret {
            secret_name = "thanos-objstore-config"
          }
        }

        volume {
          name = "thanos-data-volume"
          empty_dir {}
        }

      }
    }
  }
}

resource "kubernetes_deployment" "thanos-compactor" {

  metadata {
    name      = "thanos-compactor"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "thanos-compactor"
      }
    }

    template {
      metadata {
        labels = {
          app = "thanos-compactor"
        }
      }

      spec {
        security_context {
          fs_group = 1001
        }

        container {
          image = "${var.tsc_package_repo}:${var.thanos_image}-${var.thanos_version}"
          name  = "thanos-compactor"

          security_context {
            run_as_user  = 1001
            run_as_group = 1001

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

          args = [
            "compact",
            "--log.level=info",
            "--data-dir=/data",
            "--objstore.config-file=/config/thanos.yaml",
            "--retention.resolution-raw=${var.thanos_retention_raw}",
            "--retention.resolution-5m=${var.thanos_retention_5m}",
            "--retention.resolution-1h=${var.thanos_retention_1h}",
            "--wait",
          ]

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = "http"
            }
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = "http"
            }
          }

          port {
            container_port = 10902
            name           = "http"
          }

          resources {
            limits = {
              cpu    = 1
              memory = var.thanos_compactor_mem
            }
            requests = {
              cpu    = var.thanos_app_cpu
              memory = var.thanos_compactor_mem
            }
          }

          volume_mount {
            mount_path = "/config/"
            name       = "thanos-config-volume"
            read_only  = true
          }

          volume_mount {
            mount_path = "/data" # Mounting the /data directory to a writable volume
            name       = "thanos-data-volume"
          }
        }

        volume {
          name = "thanos-config-volume"
          secret {
            secret_name = "thanos-objstore-config"
          }
        }

        volume {
          name = "thanos-data-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume.thanos.id
          }
        }

      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "thanos" {
  metadata {
    name      = "thanos-data-compact"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.thanos_compactor_disk}Gi"
      }
    }
    storage_class_name = "default"
  }
}


resource "kubernetes_persistent_volume" "thanos" {
  metadata {
    name = "thanos-data-compact"
  }
  spec {
    capacity = {
      storage = "${var.thanos_compactor_disk}Gi"
    }
    claim_ref {
      name      = "thanos-data-compact"
      namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    }
    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Delete"
    storage_class_name               = "default"
    persistent_volume_source {
      csi {
        driver        = "disk.csi.azure.com"
        volume_handle = azurerm_managed_disk.thanos_disk.id
      }
    }
  }
}

resource "azurerm_managed_disk" "thanos_disk" {
  name                 = "${var.resource_prefix}-tsc-${var.environment}-disk"
  location             = data.azurerm_resource_group.resource_group.location
  resource_group_name  = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-rg"
  storage_account_type = "StandardSSD_ZRS"
  create_option        = "Empty"
  disk_size_gb         = var.thanos_compactor_disk

  lifecycle { ignore_changes = [tags] }
}

data "azurerm_key_vault_secret" "thanos_auth" {
  name         = "THANOS-AUTH"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "kubernetes_secret" "thanos_basic_auth" {
  metadata {
    name      = "thanos-basic-auth"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    auth = data.azurerm_key_vault_secret.thanos_auth.value
  }
}

resource "kubernetes_ingress_v1" "thanos_ingress" {

  wait_for_load_balancer = true
  metadata {
    name      = "thanos"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/auth-type"   = "basic"
      "nginx.ingress.kubernetes.io/auth-secret" = kubernetes_secret.thanos_basic_auth.metadata[0].name
      "nginx.ingress.kubernetes.io/auth-realm"  = "Authentication Required"
    }
  }
  spec {
    ingress_class_name = local.ingress_class_name
    rule {
      host = "thanos.${module.cluster_data.ingress_domain}"
      http {
        path {
          backend {
            service {
              name = "thanos-querier"
              port {
                number = kubernetes_service.thanos-querier.spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }
}
