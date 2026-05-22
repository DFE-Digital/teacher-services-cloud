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
    "$connections" = jsonencode({
      "teams-api" : {
        "connectionId" : "${azurerm_api_connection.teams-api.id}"
        "connectionName" : "${azurerm_api_connection.teams-api.name}"
        "connectionProperties" : {},
        "id" : "${azurerm_api_connection.teams-api.managed_api_id}"
      }
    })
  }

  workflow_parameters = {
    "$connections" = "{\"defaultValue\":{},\"type\":\"Object\"}"
    tenantId       = "{\"defaultValue\":\"#@platform.education.gov.uk\",\"type\":\"String\"}"
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


resource "azurerm_api_connection" "teams-api" {
  display_name        = "Robert.GWENTER@EDUCATION.GOV.UK"
  managed_api_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/uksouth/managedApis/teams"
  name                = "s189d01-tsc-mn-teams-rdg"
  parameter_values    = {}
  resource_group_name = "s189d01-tsc-mn-rg"

  lifecycle {
    # NOTE: since the connectionString is a secure value it's not returned from the API
    ignore_changes = [
      "parameter_values",
      tags
    ]
  }
}
