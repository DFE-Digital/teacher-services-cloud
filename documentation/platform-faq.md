# Platform FAQ

## Github actions OIDC
- Terraform *azurerm* provider:
  ```
  Error: Error building ARM Config: obtain subscription(***) from Azure CLI: parsing json result from the Azure CLI: waiting for the Azure CLI: exit status 1:   ERROR: Please run 'az login' to setup account.
  ```
  *azure/login* Github actions:
  ```
  Error: Please make sure to give write permissions to id-token in the workflow.
  Error: Login failed with Error: Error message: Unable to get ACTIONS_ID_TOKEN_REQUEST_URL env variable. Double check if the 'auth-type' is correct. Refer to https://github.com/Azure/login#readme for more information.
  ```
  - The permissions block may be missing. See [deploy-to-aks example](https://github.com/DFE-Digital/github-actions/tree/master/deploy-to-aks#example).
- ```
  Warning: Can't add secret mask for empty string in ##[add-mask] command.
  ```
  - Some secrets may not be present or be empty.
- ```
  Error from server (Forbidden): deployments.apps is forbidden: User "e15248ce-c1f1-4998-9b98-6c441835139d" cannot list resource "deployments" in API group "apps" at the cluster scope: User does not have access to the resource in Azure. Update role assignment to allow access.
  error: unknown shorthand flag: 'f' in -f
  See 'kubectl --help' for usage.
  Error from server (Forbidden): deployments.apps "konduit-app-8980" is forbidden: User "e15248ce-c1f1-4998-9b98-6c441835139d" cannot get resource "deployments" in API group "apps" in the namespace "default": User does not have access to the resource in Azure. Update role assignment to allow access.
  ```
  - User is not cluster admin and `kubectl -n <namespace>` argument is not used.
- Unexpected login results on command line
  - Some environment variables may be present when they should not be. Check they are not declared: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_AUTHORITY_HOST`, `AAD_LOGIN_METHOD`, `AAD_SERVICE_PRINCIPAL_CLIENT_ID`, `AAD_SERVICE_PRINCIPAL_CLIENT_SECRET`
- ```
  Error: Get "https://s189t01-tsc-test-56a40a16.hcp.uksouth.azmk8s.io:443/api/v1/namespaces/bat-qa/configmaps/ittms-1281-f15b183e44525b5c1fa1d13e928736fab58ca4ca": getting credentials: exec: executable kubelogin failed with exit code 1
  ```
  - kubelogin is failing silently in terraform. Run terraform with warning log level. Example:
    ```
    TF_LOG=warn make ci ${{ inputs.environment }} terraform-apply
    ```
    Shows error message from kubelogin:
    ```
    2025-01-03T15:20:05.796Z [WARN]  unexpected data: registry.terraform.io/hashicorp/kubernetes:stderr="Error: tenantID cannot be empty"
    ```
- ```
  ERROR: (Forbidden) Caller is not authorized to perform action on resource.
  ```

  or

  ```
  │ Error: Failed to get existing workspaces: Error retrieving keys for Storage Account "s189t01ctptfstatedvsa": storage.AccountsClient#ListKeys: Failure responding to request: StatusCode=403 -- Original Error: autorest/azure: Service returned an error. Status=403 Code="AuthorizationFailed" Message="The client '202cf44d-8ab7-4e03-b132-1c12eb1cc3ab' with object id '202cf44d-8ab7-4e03-b132-1c12eb1cc3ab' does not have authorization to perform action 'Microsoft.Storage/storageAccounts/listKeys/action' over scope '/subscriptions/***/resourceGroups/s189t01-ctp-dv-rg/providers/Microsoft.Storage/storageAccounts/s189t01ctptfstatedvsa' or the scope is invalid. If access was recently granted, please refresh your credentials."
  ```

  Authorisation failures may be caused by:
  - The federated credential for this environment does not exist
  - The managed identity does not exist
  - The managed identity is not added to the Entra ID group
  - The Entra ID group is missing the role assignement

  The managed identity should be added to the relevant Entra ID group via the `add member` option. If you cannot select this, validate you are an owner. Being an owner is required to add the managed identity to the Entra ID group.

- ```
  Error: The subscription of '***' doesn't exist in cloud 'AzureCloud'.
  Error: Login failed with Error: The process '/usr/bin/az' failed with exit code 1. Double check if the 'auth-type' is correct. Refer to https://github.com/Azure/login#readme for more information.
  ```
  The error may be caused by:
  - AZURE_SUBSCRIPTION_ID is not correct
  - The service principal doesn't have access to the subscription
