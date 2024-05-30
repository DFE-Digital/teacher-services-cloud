# Azure resources to enable Workload Identity Federation (WIF) between namespaces and Google service accounts
# Applications bind to the gcp-wif service account to populate the required environment variables

resource "azurerm_user_assigned_identity" "gcp_wif" {
  for_each = toset(var.gcp_wif_namespaces)

  location            = data.azurerm_resource_group.resource_group.location
  name                = "${var.resource_prefix}-gcp-wif-${var.environment}-${each.key}-id"
  resource_group_name = var.resource_group_name
}

resource "kubernetes_service_account" "gcp_wif" {
  for_each = toset(var.gcp_wif_namespaces)

  metadata {
    name      = "gcp-wif"
    namespace = each.key

    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.gcp_wif[each.key].client_id
    }
  }
}

resource "azurerm_federated_identity_credential" "gcp_wif" {
  for_each = toset(var.gcp_wif_namespaces)

  name                = "${var.environment}-${each.key}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.gcp_wif[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:${each.key}:${kubernetes_service_account.gcp_wif[each.key].metadata[0].name}"
}
