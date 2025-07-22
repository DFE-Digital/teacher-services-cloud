resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods", ]
    verbs      = ["get", "list", "watch", ]
  }

  rule {
    api_groups = ["extensions", ]
    resources  = ["ingresses", ]
    verbs      = ["get", "list", "watch", ]
  }

  rule {
    non_resource_urls = ["/metrics", ]
    verbs             = ["get", ]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "monitoring"
  }
}

resource "kubernetes_config_map" "prometheus" {
  metadata {
    name      = "prometheus-server-conf"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "prometheus.yml" = file("${path.module}/config/prometheus/${var.config}.prometheus.yml")
  }
}

resource "kubernetes_config_map" "prometheus-rules" {
  metadata {
    name      = "prometheus-rules-conf"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "app.alert.rules"  = local.app_alert_rules
    "node.alert.rules" = local.node_alert_rules
  }
}

resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "monitoring"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app              = "prometheus"
          thanos-store-api = true
        }
      }

      spec {
        container {
          image = "prom/prometheus:${var.prometheus_version}"
          name  = "prometheus"

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
            "--storage.tsdb.retention.time=${var.prometheus_tsdb_retention_time}",
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus/",
            "--web.enable-lifecycle",
            "--storage.tsdb.no-lockfile",
            "--storage.tsdb.min-block-duration=2h",
            "--storage.tsdb.max-block-duration=2h",
          ]

          port {
            container_port = 9090
          }

          resources {
            limits = {
              cpu    = 1
              memory = var.prometheus_app_mem
            }
            requests = {
              cpu    = var.prometheus_app_cpu
              memory = var.prometheus_app_mem
            }
          }

          volume_mount {
            mount_path = "/etc/prometheus/"
            name       = "prometheus-config-volume"
          }

          volume_mount {
            mount_path = "/prometheus/"
            name       = "prometheus-storage-volume"
          }

          volume_mount {
            mount_path = "/etc/prometheus-rules/"
            name       = "prometheus-rules-volume"
          }
        }

        volume {
          name = "prometheus-config-volume"
          config_map {
            #              default_mode = "0420"
            name = kubernetes_config_map.prometheus.metadata[0].name
          }
        }

        volume {
          name = "prometheus-storage-volume"
          empty_dir {}
        }

        volume {
          name = "prometheus-rules-volume"
          config_map {
            name = kubernetes_config_map.prometheus-rules.metadata[0].name
          }
        }

        container {
          image = "quay.io/thanos/thanos:${var.thanos_version}"
          name  = "thanos"

          args = [
            "sidecar",
            "--log.level=info",
            "--tsdb.path=/prometheus",
            "--prometheus.url=http://127.0.0.1:9090",
            "--objstore.config-file=/config/thanos.yaml",
            "--reloader.config-file=/etc/prometheus/prometheus.yml",
            "--reloader.rule-dir=/etc/prometheus-rules/",
          ]

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = "http-sidecar"
            }
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = "http-sidecar"
            }
          }

          port {
            container_port = 10902
            name           = "http-sidecar"
          }

          port {
            container_port = 10901
            name           = "grpc"
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
            mount_path = "/etc/prometheus/"
            name       = "prometheus-config-volume"
          }

          volume_mount {
            mount_path = "/prometheus/"
            name       = "prometheus-storage-volume"
          }

          volume_mount {
            mount_path = "/config/"
            name       = "thanos-config-volume"
            read_only  = true
          }

          volume_mount {
            mount_path = "/etc/prometheus-rules/"
            name       = "prometheus-rules-volume"
          }
        }

        volume {
          name = "thanos-config-volume"
          secret {
            secret_name = kubernetes_secret.thanos.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "monitoring"
    annotations = {
      "prometheus.io/port"   = "9090"
      "prometheus.io/scrape" = "true"
    }
  }

  spec {
    port {
      name        = "prometheus"
      port        = 8080
      target_port = kubernetes_deployment.prometheus.spec[0].template[0].spec[0].container[0].port[0].container_port
    }
    selector = {
      app = "prometheus"
    }
  }
}

data "azurerm_key_vault_secret" "prometheus_auth" {
  name         = "PROMETHEUS-AUTH"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "kubernetes_secret" "prometheus_basic_auth" {
  metadata {
    name      = "prometheus-basic-auth"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    auth = data.azurerm_key_vault_secret.prometheus_auth.value
  }
}

resource "kubernetes_ingress_v1" "prometheus_ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/auth-type"   = "basic"
      "nginx.ingress.kubernetes.io/auth-secret" = kubernetes_secret.prometheus_basic_auth.metadata[0].name
      "nginx.ingress.kubernetes.io/auth-realm"  = "Authentication Required"
    }
  }
  spec {
    ingress_class_name = local.ingress_class_name
    rule {
      host = "prometheus.${module.cluster_data.ingress_domain}"
      http {
        path {
          backend {
            service {
              name = "prometheus"
              port {
                number = kubernetes_service.prometheus.spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }
}
