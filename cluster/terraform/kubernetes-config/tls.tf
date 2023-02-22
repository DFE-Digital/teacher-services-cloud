data "azurerm_key_vault" "cert_kv" {
  name                = var.cluster_kv
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_certificate_data" "cert" {
  name         = local.cluster_cert_secret
  key_vault_id = data.azurerm_key_vault.cert_kv.id
}

locals {
  # The cert from the KV contains the full chain and is in the wrong order
  # So we need to extract the primary cert which is the last in the list
  # See https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/tls.md

  full_cert             = data.azurerm_key_vault_certificate_data.cert.pem
  cert_one_line         = replace(local.full_cert, "\n", "")
  primary_cert_one_line = regexall("-----BEGIN CERTIFICATE-----[^-]*-----END CERTIFICATE-----", local.cert_one_line)[2]

  primary_cert = replace(
    replace(
      local.primary_cert_one_line,
      "CERTIFICATE-----", "CERTIFICATE-----\n"
    ),
    "-----END", "\n-----END"
  )
}

resource "kubernetes_secret_v1" "kube_cert_secret" {
  metadata {
    name      = "cert-secret"
    namespace = "default"
  }

  data = {
    "tls.crt" = local.primary_cert
    "tls.key" = data.azurerm_key_vault_certificate_data.cert.key
  }

  type = "kubernetes.io/tls"
}
