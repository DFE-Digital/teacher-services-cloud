resource "azurerm_user_assigned_identity" "ga_wif" {
  for_each = var.ga_wif_managed_id

  location            = data.azurerm_resource_group.resource_group.location
  name                = "${var.resource_prefix}-ga-wif-${var.config}-${each.key}-id"
  resource_group_name = var.resource_group_name
}

locals {
  # Iterate over ga_wif_namespaces, repos and environments to create a list of maps
  ga_wif_credentials = flatten([
    for group, repos in var.ga_wif_managed_id : [
      for repo, environments in repos : [
        for environment in environments : {
          g = group
          r = repo
          e = environment
        }
      ]
    ]
  ])
}

resource "azurerm_federated_identity_credential" "github_actions_wif" {
  for_each = {
    # Create a map from the list by generating unique keys
    for creds in local.ga_wif_credentials : "${creds.r}-${creds.e}" => creds
  }

  name                = each.key
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.ga_wif[each.value.g].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:DFE-Digital/${each.value.r}:environment:${each.value.e}"
}
