resource "azurerm_user_assigned_identity" "ga_wif" {
  for_each = var.ga_wif_namespaces

  location            = data.azurerm_resource_group.resource_group.location
  name                = "${var.resource_prefix}-ga-wif-${var.config}-${each.key}-id"
  resource_group_name = var.resource_group_name
}

locals {
  # Iterate over ga_wif_namespaces, repos and environments to create a list of maps
  ga_wif_credentials = flatten([
    for namespace, repos in var.ga_wif_namespaces : [
      for repo, environments in repos : [
        for environment in environments : {
          n = namespace
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
    for creds in local.ga_wif_credentials: "${creds.r}-${creds.e}" => creds
  }

  name                = each.key
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.ga_wif[each.value.n].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:DFE-Digital/${each.value.r}:environment:${each.value.e}"
}
