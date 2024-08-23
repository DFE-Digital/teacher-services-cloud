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
          env {
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "true"
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ORG_NAME"
            value = "Main Org."
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ORG_ROLE"
            value = "Viewer"
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

          volume_mount {
            name       = "grafana-dashboard-provisioning"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }

          volume_mount {

            name       = "grafana-dashboards"
            mount_path = "/var/lib/grafana/dashboards"
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
        volume {
          name = "grafana-dashboard-provisioning"
          config_map {
            name = kubernetes_config_map.grafana_dashboard_provisioning.metadata[0].name
          }
        }
        volume {
          name = "grafana-dashboards"
          config_map {
            name = kubernetes_config_map.grafana_dashboards.metadata[0].name
          }
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

resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "k8s-addons-prometheus.json"    = file("${path.module}/config/dashboards/k8s-addons-prometheus.json")
    "k8s-system-api-server.json"    = file("${path.module}/config/dashboards/k8s-system-api-server.json")
    "k8s-views-global.json"         = file("${path.module}/config/dashboards/k8s-views-global.json")
    "k8s-views-namespaces.json"     = file("${path.module}/config/dashboards/k8s-views-namespaces.json")
    "k8s-views-nodes.json"          = file("${path.module}/config/dashboards/k8s-views-nodes.json")
    "k8s-views-pod.json"            = file("${path.module}/config/dashboards/k8s-views-pod.json")
    "nginx-ingress-controller.json" = file("${path.module}/config/dashboards/nginx-ingress-controller.json")

  }
}
resource "kubernetes_config_map" "grafana_dashboard_provisioning" {
  metadata {
    name      = "grafana-dashboard-provisioning"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "dashboards.yaml" = file("${path.module}/config/dashboards.yaml")
  }
}

resource "kubernetes_ingress_v1" "grafana_ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }
  spec {
    ingress_class_name = local.ingress_class_name
    rule {
      host = "grafana.${module.cluster_data.ingress_domain}"
      http {
        path {
          backend {
            service {
              name = "grafana"
              port {
                number = kubernetes_service.grafana_service.spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }
}
