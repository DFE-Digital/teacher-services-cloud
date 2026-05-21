# -----------------------------
# Logic App (Consumption)
# -----------------------------
resource "azurerm_logic_app_workflow" "consumption" {
  count = var.logic_app_type == "Consumption" ? 1 : 0

  enabled             = true
  name                = var.name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name

  parameters = {
    #"$connections" = "{\"teams\":{\"connectionId\":\"/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/resourceGroups/s189d01-tsc-mn-rg/providers/Microsoft.Web/connections/teams-1\",\"connectionName\":\"teams-1\",\"connectionProperties\":{},\"id\":\"/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/providers/Microsoft.Web/locations/uksouth/managedApis/teams\"},\"teams-1\":{\"connectionId\":\"/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/resourceGroups/s189d01-tsc-mn-rg/providers/Microsoft.Web/connections/teams-1\",\"connectionName\":\"teams-1\",\"connectionProperties\":{},\"id\":\"/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/providers/Microsoft.Web/locations/uksouth/managedApis/teams\"}}"
    "$connections" = jsonencode({
      "teams" : {
        "connectionId" : "/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/resourceGroups/s189d01-tsc-mn-rg/providers/Microsoft.Web/connections/teams-1"
        "connectionName" : "teams-1"
        "connectionProperties" : {},
        "id" : "/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/providers/Microsoft.Web/locations/uksouth/managedApis/teams"
      },
      "teams-1" : {
        "connectionId" : "/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/resourceGroups/s189d01-tsc-mn-rg/providers/Microsoft.Web/connections/teams-1",
        "connectionName" : "teams-1",
        "connectionProperties" : {},
        "id" : "/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/providers/Microsoft.Web/locations/uksouth/managedApis/teams"
      }
    })
  }

  workflow_parameters = {
    "$connections" = "{\"defaultValue\":{},\"type\":\"Object\"}"
  }

  workflow_schema  = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version = "1.0.0.0"

  #identity {
  #  type = local.identity_type
  #}

  /*
  access_control {
    trigger {
      allowed_caller_ip_address_range = ["*"]

      open_authentication_policy {
        name = "ad-auth"

        claim {
          name  = "Issuer"
          value = "https://sts.windows.net/${data.azuread_client_config.current.tenant_id}/"
        }

        claim {
          name  = "Audience"
          value = "https://management.azure.com/"
        }
      }
    }
  }
*/

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
