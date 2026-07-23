data "azurerm_key_vault" "key_vault" {
  name                = var.cluster_kv
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secrets" "this" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_key_vault_secret" "this" {
  for_each     = toset(data.azurerm_key_vault_secrets.this.names)
  name         = each.key
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_subscription" "current" {
}

data "azurerm_resource_group" "this" {
  name = var.alerting_resource_group_name
}

locals {
  core_name                   = "teams-alerts"
  logic_app_name              = "${var.resource_prefix}-tsc-${local.core_name}-${var.environment}"
  api_connection_name         = "${var.resource_prefix}-tsc-${local.core_name}-${var.environment}"
  api_connection_display_name = "${var.resource_prefix}-tsc-${local.core_name}-${var.environment}"
}

resource "azapi_resource" "consumption" {
  type      = "Microsoft.Logic/workflows@2019-05-01"
  name      = local.logic_app_name
  parent_id = data.azurerm_resource_group.this.id
  location  = data.azurerm_resource_group.this.location

  body = {
    properties = {
      definition = jsondecode(file("${path.module}/workflows/azure_alert_to_teams_notifications.json"))

      parameters = {
        tenantId              = { value = "#@platform.education.gov.uk" }
        ShortCodeToId         = { value = { mapping = jsondecode(data.azurerm_key_vault_secret.this["SHORT-CODE-TO-TEAMS-CHANNEL"].value) } }
        defaultChannelGroupId = { value = data.azurerm_key_vault_secret.this["AZ-ALERTS-DEFAULT-TEAMS-CHANNEL-GROUPID"].value }
        defaultChannelId      = { value = data.azurerm_key_vault_secret.this["AZ-ALERTS-DEFAULT-TEAMS-CHANNEL-ID"].value }
        "$connections" = {
          value = {
            teams = {
              connectionId         = azurerm_api_connection.teams-api.id
              connectionName       = "teams"
              connectionProperties = {}
              id                   = azurerm_api_connection.teams-api.managed_api_id
            }
          }
        }
      }
    }
  }

  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  schema_validation_enabled = true

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  depends_on = [azurerm_api_connection.teams-api]
}

resource "azurerm_api_connection" "teams-api" {
  display_name        = local.api_connection_display_name
  managed_api_id      = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/providers/Microsoft.Web/locations/uksouth/managedApis/teams"
  name                = local.api_connection_name
  parameter_values    = {}
  resource_group_name = var.alerting_resource_group_name

  lifecycle {
    # NOTE: since the connectionString is a secure value it's not returned from the API
    ignore_changes = [
      parameter_values,
      tags
    ]
  }
}
