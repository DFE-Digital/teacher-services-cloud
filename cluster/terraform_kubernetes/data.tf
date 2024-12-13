data "azurerm_key_vault" "key_vault" {
  name                = var.cluster_kv
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secrets" "main" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_subscription" "current" {}
