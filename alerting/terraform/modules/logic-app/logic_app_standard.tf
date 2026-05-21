# -----------------------------
# Logic App (Standard)
# -----------------------------
resource "azurerm_service_plan" "this" {
  count               = var.logic_app_type == "Standard" ? 1 : 0
  name                = "${var.name}-plan"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name

  os_type  = "Windows"
  sku_name = "WS1"

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_storage_account" "this" {
  count               = var.logic_app_type == "Standard" ? 1 : 0
  name                = lower(replace("${var.name}sa", "/[^a-z0-9]/", ""))
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name

  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_logic_app_standard" "standard" {
  count               = var.logic_app_type == "Standard" ? 1 : 0
  name                = var.name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name


  app_service_plan_id        = azurerm_service_plan.this[0].id
  storage_account_name       = azurerm_storage_account.this[0].name
  storage_account_access_key = azurerm_storage_account.this[0].primary_access_key

  identity {
    type = local.identity_type
  }

  site_config {}

  app_settings = merge(
    {
      "FUNCTIONS_WORKER_RUNTIME" = "node"
      "WEBSITE_RUN_FROM_PACKAGE" = "1"
    }
  )

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
