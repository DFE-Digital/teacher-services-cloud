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
    namespace = "monitoring"
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
          image = "quay.io/thanos/thanos:${var.thanos_version}"
          name  = "thanos-querier"

          args = [
            "query",
            "--log.level=debug",
            "--query.replica-label=replica",
            "--store=dns+thanos-store-gateway:10901",
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
              memory = var.thanos_app_mem
            }
            requests = {
              cpu    = var.thanos_app_cpu
              memory = var.thanos_app_mem
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
          image = "quay.io/thanos/thanos:${var.thanos_version}"
          name  = "thanos-store-gateway"

          args = [
            "store",
            "--log.level=debug",
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
              memory = var.thanos_app_mem
            }
            requests = {
              cpu    = var.thanos_app_cpu
              memory = var.thanos_app_mem
            }
          }

          volume_mount {
            mount_path = "/config/"
            name       = "thanos-config-volume"
            read_only  = true
          }
        }

        volume {
          name = "thanos-config-volume"
          secret {
            secret_name = "thanos-objstore-config"
          }
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

        container {
          image = "quay.io/thanos/thanos:${var.thanos_version}"
          name  = "thanos-compactor"

          args = [
            "compact",
            "--log.level=debug",
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
              memory = var.thanos_app_mem
            }
            requests = {
              cpu    = var.thanos_app_cpu
              memory = var.thanos_app_mem
            }
          }

          volume_mount {
            mount_path = "/config/"
            name       = "thanos-config-volume"
            read_only  = true
          }
        }

        volume {
          name = "thanos-config-volume"
          secret {
            secret_name = "thanos-objstore-config"
          }
        }

      }
    }
  }
}
