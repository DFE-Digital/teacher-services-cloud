resource "azurerm_user_assigned_identity" "ga_wif" {
  for_each = var.ga_wif_managed_id

  location            = data.azurerm_resource_group.resource_group.location
  name                = "${var.resource_prefix}-ga-wif-${var.environment}-${each.key}-id"
  resource_group_name = var.resource_group_name
}

locals {
  # Iterate over ga_wif_namespaces, repos and environments to create a list of maps
  # owner ID for immutable repos is hardcoded to the DfE Digital org ID, which is 30029772.
  ga_wif_credentials = flatten([
    for group, repos in var.ga_wif_managed_id : [
      for repo, environments in repos : [
        for environment in environments : {
          group       = group
          repo        = repo
          environment = environment
          subject     = "repo:DFE-Digital${contains(keys(var.ga_wif_immutable_repos), repo) ? "@30029772" : ""}/${repo}${contains(keys(var.ga_wif_immutable_repos), repo) ? "@${var.ga_wif_immutable_repos[repo].repo_id}" : ""}:environment:${environment}"
        }
      ]
    ]
  ])
}

resource "azurerm_federated_identity_credential" "github_actions_wif" {
  for_each = {
    # Create a map from the list by generating unique keys
    for creds in local.ga_wif_credentials : "${creds.repo}-${creds.environment}" => creds
  }

  name      = each.key
  parent_id = azurerm_user_assigned_identity.ga_wif[each.value.group].id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = each.value.subject
}