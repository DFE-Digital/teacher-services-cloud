locals {
  cluster_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-${var.environment}-aks" :
    "${var.resource_prefix}aks-tsc-${var.environment}"
  )

  kubelogin_github_actions_args = [
    "get-token",
    "--server-id",
    "6dae42f8-4368-4678-94ff-3960e28e3630" # See https://azure.github.io/kubelogin/concepts/aks.html
  ]
  kubelogin_azurecli_args = [
    "get-token",
    "--login",
    "azurecli",
    "--server-id",
    "6dae42f8-4368-4678-94ff-3960e28e3630"
  ]
  running_in_github_actions = contains(keys(data.environment_variables.github_actions.items), "GITHUB_ACTIONS")
  # If running in github actions, AAD_LOGIN_METHOD determines the login method, either workloadidentity or spn
  # If not, use azurecli explicitly as command line argument
  kubelogin_args = (local.running_in_github_actions ?
    local.kubelogin_github_actions_args :
    local.kubelogin_azurecli_args
  )

}