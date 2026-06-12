locals {
  #Think we'll need to use UserAssigned, alt is SystemAssigned
  identity_type = "UserAssigned"
  workflow_parameters = {
    #"$connections" = "{\"teams\":{\"connectionId\":\"/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/resourceGroups/s189d01-tsc-mn-rg/providers/Microsoft.Web/connections/teams-1\",\"connectionName\":\"teams-1\",\"connectionProperties\":{},\"id\":\"/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/providers/Microsoft.Web/locations/uksouth/managedApis/teams\"},\"teams-1\":{\"connectionId\":\"/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/resourceGroups/s189d01-tsc-mn-rg/providers/Microsoft.Web/connections/teams-1\",\"connectionName\":\"teams-1\",\"connectionProperties\":{},\"id\":\"/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/providers/Microsoft.Web/locations/uksouth/managedApis/teams\"}}"
  }

  logic_app_base_url = element(regex("^(https?:\\/\\/[^\\/:?#]+)",azurerm_logic_app_workflow.consumption[0].access_endpoint),0)

}
