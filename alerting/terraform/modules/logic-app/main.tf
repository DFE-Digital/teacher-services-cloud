data "azuread_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}
