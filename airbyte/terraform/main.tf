module "cluster_data" {
  source = "./vendor/modules/aks//aks/cluster_data"
  name   = var.environment
}

data "azurerm_key_vault" "key_vault" {
  name                = var.cluster_kv
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secrets" "main" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_key_vault_secret" "airbyte_pass" {
  for_each = toset(var.airbyte_namespaces)

  name         = "AIRBYTE-PASS-${each.key}"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_user_assigned_identity" "gcp_wif" {
  for_each = toset(var.airbyte_namespaces)

  name                = "${var.resource_prefix}-gcp-wif-${var.environment}-${each.key}-id"
  resource_group_name = var.resource_group_name
}

resource "random_password" "client-id" {
  for_each = toset(var.airbyte_namespaces)

  length  = 37
  special = false
  upper   = false
}

resource "random_password" "client-secret" {
  for_each = toset(var.airbyte_namespaces)

  length  = 32
  special = false
  upper   = true
}

resource "kubernetes_secret" "airbyte_secret" {
  for_each = toset(var.airbyte_namespaces)

  metadata {
    name      = "airbyte-auth-secrets"
    namespace = "${each.key}"
  }

  lifecycle {
    ignore_changes = [data]
  }

}

# Had to separate the data from the secret, as airbye auth creates a jwt token that breaks the service if removed
# Works with force=true although I'm not convinced I'm using this the way it should
# i.e. the base secret shouldn't be created in this terraform
resource "kubernetes_secret_v1_data" "airbyte_secret_data" {
  for_each = toset(var.airbyte_namespaces)

  metadata {
    name = "airbyte-auth-secrets"
    namespace = "${each.key}"
  }
  data = {
    instance-admin-password = data.azurerm_key_vault_secret.airbyte_pass["${each.key}"].value
    instance-admin-client-id = random_password.client-id["${each.key}"].result
    instance-admin-client-secret = random_password.client-secret["${each.key}"].result
  }
  force = true
}

resource "kubernetes_ingress_v1" "airbyte_ingress" {
  for_each = toset(var.airbyte_namespaces)

  wait_for_load_balancer = true
  metadata {
    name      = "airbyte-${each.key}-ingress"
    namespace = "${each.key}"
    annotations = {
    #   "nginx.ingress.kubernetes.io/auth-type"   = "basic"
    #   "nginx.ingress.kubernetes.io/auth-secret" = kubernetes_secret.airbyte_basic_auth.metadata[0].name
    #   "nginx.ingress.kubernetes.io/auth-realm"  = "Authentication Required"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "airbyte-${each.key}.${module.cluster_data.ingress_domain}"
      http {
        path {
          backend {
            service {
              name = "airbyte-${each.key}-airbyte-webapp-svc"
              port {
                number = 80
              }
            }
          }
          path = "/"
          path_type = "Prefix"
        }
      }
    }
  }
}
