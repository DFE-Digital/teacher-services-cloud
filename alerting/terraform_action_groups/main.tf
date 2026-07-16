locals {
  core_name      = "teams-alerts"
  logic_app_name = "${var.resource_prefix}-tsc-${local.core_name}-${var.environment}"
}


data "azurerm_logic_app_workflow" "consumption" {
  name                = local.logic_app_name
  resource_group_name = var.alerting_resource_group_name
}

/*
We're using AzAPI to allow us to allow us to update (repeatedly) existing Action Groups, it'll add a link to the Logic App receiver leaving everything else as is.
See the locals section below for how we handle already existing logic App receivers.
Note: This will NOT create a new Action Group (but can be changed to).
*/


resource "azapi_update_resource" "action_groups" {
  for_each = local.action_groups_needing_update

  type        = "Microsoft.Insights/actionGroups@2024-10-01-preview"
  resource_id = each.value.id

  body = {
    properties = {
      logicAppReceivers = concat(
        [
          for r in each.value.logic_app_receiver : {
            callbackUrl          = r.callback_url
            name                 = r.name
            resourceId           = r.resource_id
            useCommonAlertSchema = r.use_common_alert_schema
          }
        ],
        [local.new_receiver]
      )
    }
  }
}


/*
As we're only updating existing action groups we do a lookup here to get the IDs.
We could pass IDs through from the parent module, and that'd make sense but we need to get the resource details so we can lookup
logicAppReceivers and avoid adding duplicates so it doesn't benefit us to pass through IDs.
*/
data "azurerm_monitor_action_group" "action_group" {
  for_each = var.action_groups_to_hookup

  resource_group_name = each.value.resource_group_name
  name                = each.value.name
}

/*
This get existing action groups and reads any existing logic app receivers (aka targets)
Using the local it'll preserve the existing receiver's name and only add a new receiver when the resourceId doesn't already exist
*/


locals {
  new_receiver = {
    callbackUrl          = "https://logicapptriggerurl/..."
    name                 = "tsc-teams-alerting-${var.environment}"
    resourceId           = data.azurerm_logic_app_workflow.consumption.id
    useCommonAlertSchema = true
  }


  action_groups_needing_update = {
    for id, ag in data.azurerm_monitor_action_group.action_group :
    id => ag
    if !contains(
      [
        for r in ag.logic_app_receiver :
        r.resource_id
      ],
      local.new_receiver.resourceId
    )
  }
}
