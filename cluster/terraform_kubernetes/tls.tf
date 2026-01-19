data "azurerm_key_vault" "cert_kv" {
  name                = var.cluster_kv
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_certificate_data" "cert" {
  name         = local.cluster_cert_secret
  key_vault_id = data.azurerm_key_vault.cert_kv.id
}

locals {
  # The cert from the KV contains the full chain and is in the wrong order: Root CA -> Intermediate CA -> End-user certificate
  # We use terraform string manipulation to make the order compliant with the TLS RFC: End-user certificate -> Intermediate CA -> Root CA
  # See https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/tls.md

  original_cert_chain           = data.azurerm_key_vault_certificate_data.cert.pem
  original_cert_chain_one_line  = replace(local.original_cert_chain, "\n", "")
  certificate_list              = regexall("-----BEGIN CERTIFICATE-----[^-]*-----END CERTIFICATE-----", local.original_cert_chain_one_line)
  root_ca_cert_one_line         = local.certificate_list[0]
  intermediate_ca_cert_one_line = local.certificate_list[1]
  end_user_cert_one_line        = local.certificate_list[2]
  reversed_chain_one_line       = "${local.end_user_cert_one_line}${local.intermediate_ca_cert_one_line}${local.root_ca_cert_one_line}"
  reversed_full_cert = replace(
    replace(
      local.reversed_chain_one_line,
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
    "tls.crt" = local.reversed_full_cert
    "tls.key" = data.azurerm_key_vault_certificate_data.cert.key
  }

  type = "kubernetes.io/tls"
}

resource "kubernetes_secret_v1" "kube_cert_secret_monitoring" {

  metadata {
    name      = kubernetes_secret_v1.kube_cert_secret.metadata[0].name
    namespace = "monitoring"
  }

  data = kubernetes_secret_v1.kube_cert_secret.data
  type = kubernetes_secret_v1.kube_cert_secret.type
}

resource "kubernetes_secret_v1" "kube_cert_secret_infra" {

  metadata {
    name      = kubernetes_secret_v1.kube_cert_secret.metadata[0].name
    namespace = "infra"
  }

  data = kubernetes_secret_v1.kube_cert_secret.data
  type = kubernetes_secret_v1.kube_cert_secret.type
}

resource "kubernetes_secret_v1" "kube_cert_secret_clone" {
  count    = var.clone_cluster ? 1 : 0
  provider = kubernetes.clone

  metadata {
    name      = kubernetes_secret_v1.kube_cert_secret.metadata[0].name
    namespace = kubernetes_secret_v1.kube_cert_secret.metadata[0].namespace
  }

  data = kubernetes_secret_v1.kube_cert_secret.data
  type = kubernetes_secret_v1.kube_cert_secret.type
}
