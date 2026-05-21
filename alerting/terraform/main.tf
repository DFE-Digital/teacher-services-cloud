data "azuread_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

module "logic_app" {
  name                = "s189d01-tsc-logic-app-test01"
  source              =  "./modules/logic-app" #"./modules/logic-app"
  logic_app_type      = "Consumption"
  environment         = "development"
  resource_group_name = var.resource_group_name
}

resource "azurerm_monitor_metric_alert" "test" {
  name                = "monitoring-test-alert"
  resource_group_name = data.azurerm_resource_group.this.name
  scopes              = ["/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/resourceGroups/s189d01-tsc-dv-rg/providers/Microsoft.ContainerService/managedClusters/s189d01-tsc-cluster1-aks"]
  description         = "Test Alert, montior AKS"
  window_size         = "PT5M"
  frequency           = "PT1M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azapi_resource.action_group_test.id
    webhook_properties = {
      target_channels = "tsc,att"
      environment     = "development"
    }
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

# azurerm_monitor_action_group does not currently support identities, using AzAPI for now
resource "azapi_resource" "action_group_test" {
  body = {
    properties = {
      armRoleReceivers           = []
      automationRunbookReceivers = []
      azureAppPushReceivers      = []
      azureFunctionReceivers     = []
      emailReceivers             = []
      enabled                    = true
      eventHubReceivers          = []
      groupShortName             = "webhooktst"
      itsmReceivers              = []
      logicAppReceivers = [{
        callbackUrl          = "https://logicapptriggerurl/..."
        name                 = "logicappaction"
        resourceId           = module.logic_app.logic_app_id
        useCommonAlertSchema = true
      }]
      smsReceivers     = []
      voiceReceivers   = []
      webhookReceivers = []
    }
  }
  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  location                  = "global"
  name                      = "s189d01-tsc-webook-test"
  parent_id                 = data.azurerm_resource_group.this.id
  schema_validation_enabled = true

  type = "Microsoft.Insights/actiongroups@2024-10-01-preview"
  identity {
    identity_ids = [module.logic_app.identity_id]
    type         = "UserAssigned"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

/*
resource "azurerm_monitor_action_group" "test" {
  name                = "s189d01-tsc-webook-test"
  resource_group_name = local.resource_group_name
  short_name          = "webhooktst"

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  logic_app_receiver {
    name                    = "logicappaction"
    resource_id             = module.logic_app.logic_app_id
    callback_url            = "https://logicapptriggerurl/..."
    use_common_alert_schema = true
  }
*/
/*

  webhook_receiver {
    name                    = "callmyapiaswell"
    service_uri             = "http://example.com/alert"
    use_common_alert_schema = true
  }
  */
//}
