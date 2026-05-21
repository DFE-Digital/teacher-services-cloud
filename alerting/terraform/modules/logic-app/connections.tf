resource "azurerm_api_connection" "teams-api" {
  display_name        = "Robert.GWENTER@EDUCATION.GOV.UK"
  managed_api_id      = "/subscriptions/5c83eb53-a94f-4778-b258-1f33efe49655/providers/Microsoft.Web/locations/uksouth/managedApis/teams"
  name                = "teams-2"
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
