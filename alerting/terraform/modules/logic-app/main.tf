data "azuread_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

resource "azurerm_user_assigned_identity" "action_group" {
  location            = data.azurerm_resource_group.this.location
  name                = "s189d01-tsc-action_group_alerts"
  resource_group_name = data.azurerm_resource_group.this.name
}
