data "azurerm_key_vault_secret" "grafana_admin_user" {
  name         = "GRAFANA-ADMIN-USER"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_key_vault_secret" "grafana_admin_password" {
  name         = "GRAFANA-ADMIN-PASSWORD"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

# Add data sources for Azure AD application details
data "azurerm_key_vault_secret" "grafana_client_id" {
  name         = "GF-AZURE-CLIENT-ID"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_key_vault_secret" "grafana_client_secret" {
  name         = "GRAFANA-AZURE-CLIENT-ID-SECRET"
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
          image = "${var.tsc_package_repo}:grafana-${var.grafana_version}"
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
            name = "GF_SECURITY_ADMIN_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_admin_credentials.metadata[0].name
                key  = "admin-user"
              }
            }
          }
          env {
            name = "GF_SECURITY_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_admin_credentials.metadata[0].name
                key  = "admin-password"
              }
            }
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "false"
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ORG_NAME"
            value = "Main Org."
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ORG_ROLE"
            value = "Viewer"
          }
          env {
            name  = "GF_AUTH_AZUREAD_ENABLED"
            value = "true"
          }
          env {
            name  = "GF_AUTH_AZUREAD_CLIENT_ID"
            value = data.azurerm_key_vault_secret.grafana_client_id.value
          }
          env {
            name = "GF_AUTH_AZUREAD_CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_azure_credentials.metadata[0].name
                key  = "client-secret"
              }
            }
          }
          env {
            name  = "GF_AUTH_AZUREAD_CLIENT_AUTHENTICATION"
            value = "client_secret_post"
          }
          env {
            name  = "GF_AUTH_AZUREAD_TENANT_ID"
            value = data.azurerm_client_config.current.tenant_id
          }
          env {
            name  = "GF_AUTH_AZUREAD_AUTH_URL"
            value = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/oauth2/v2.0/authorize"
          }
          env {
            name  = "GF_AUTH_AZUREAD_TOKEN_URL"
            value = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/oauth2/v2.0/token"
          }
          env {
            name  = "GF_AUTH_AZUREAD_ROLE_ATTRIBUTE_PATH"
            value = "contains(roles, 'Admin') && 'Admin' || contains(roles, 'Editor') && 'Editor' || 'Viewer'"
          }
          env {
            name  = "GF_AUTH_AZUREAD_ALLOW_SIGN_UP"
            value = "true"
          }
          env {
            name  = "GF_SERVER_ROOT_URL"
            value = "https://grafana.${module.cluster_data.ingress_domain}"
          }
          env {
            name  = "GF_SERVER_SERVE_FROM_SUB_PATH"
            value = "true"
          }
          env {
            name  = "GF_AUTH_DISABLE_LOGIN_FORM"
            value = "true"
          }
          env {
            name  = "GF_AUTH_AZUREAD_ROLE_ATTRIBUTE_STRICT"
            value = "false"
          }
          env {
            name  = "GF_AUTH_AZUREAD_ALLOW_ASSIGN_GRAFANA_ADMIN"
            value = "true"
          }
          env {
            name  = "GF_AUTH_AZUREAD_SKIP_ORG_ROLE_SYNC"
            value = "false"
          }
          env {
            name  = "GF_AUTH_AZUREAD_USE_PKCE"
            value = "true"
          }
          env {
            name  = "GF_ALLOW_ASSIGN_GRAFANA_ADMIN"
            value = "true"
          }
          env {
            name  = "GF_AUTH_AZUREAD_NAME"
            value = "Azure AD"
          }
          env {
            name  = "GF_AUTH_AZUREAD_AUTO_LOGIN"
            value = "false"
          }
          env {
            name  = "GF_AUTH_AZUREAD_ALLOWED_ORGANIZATIONS"
            value = data.azurerm_client_config.current.tenant_id
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
          volume_mount {
            name       = "azure-credentials"
            mount_path = "/var/run/secrets/azure"
            read_only  = true
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
        volume {
          name = "azure-credentials"
          secret {
            secret_name = kubernetes_secret.grafana_azure_credentials.metadata[0].name
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

  data = local.grafana_dashboards_map
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

# Update the Kubernetes secret to use the key vault secret
resource "kubernetes_secret" "grafana_azure_credentials" {
  metadata {
    name      = "grafana-azure-credentials"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "client-secret" = data.azurerm_key_vault_secret.grafana_client_secret.value
  }
}

resource "kubernetes_secret" "grafana_admin_credentials" {
  metadata {
    name      = "grafana-admin-credentials"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
  }

  data = {
    "admin-user"     = data.azurerm_key_vault_secret.grafana_admin_user.value
    "admin-password" = data.azurerm_key_vault_secret.grafana_admin_password.value
  }
}
