# see https://docs.airbyte.com/platform/deploying-airbyte/integrations/storage

resource "azurerm_storage_account" "airbyte" {
  for_each = toset(var.airbyte_namespaces)

  name                            = length(each.key) > 1 ? "${var.resource_prefix}${substr(replace(each.key, "-", ""), 0, 10)}absa" : replace(each.key, "-", "")
  location                        = "uksouth"
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_storage_container" "airbyte" {
  for_each = toset(var.airbyte_namespaces)

  name                  = "airbyte-bucket"
  storage_account_name  = azurerm_storage_account.airbyte["${each.key}"].name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "main" {
  for_each = toset(var.airbyte_namespaces)

  storage_account_id = azurerm_storage_account.airbyte["${each.key}"].id

  rule {
    name    = "DeleteAfter14Days"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 14
      }
    }
  }
}

resource "kubernetes_secret" "airbyte_config_secrets" {
  for_each = toset(var.airbyte_namespaces)

  metadata {
    name      = "airbyte-config-secrets"
    namespace = "${each.key}"
  }

  data = {
    azure-blob-store-connection-string = azurerm_storage_account.airbyte["${each.key}"].primary_connection_string
  }

}
