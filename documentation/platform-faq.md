# Platform FAQ

## Github actions OIDC
- ```
  Error: Error building ARM Config: obtain subscription(***) from Azure CLI: parsing json result from the Azure CLI: waiting for the Azure CLI: exit status 1:   ERROR: Please run 'az login' to setup account.
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
  Authorisation failures may be caused by:
  - The federated credential for this environment does not exist
  - The managed identity does not exist
  - The managed identity is not added to the Entra ID group
  - The Entra ID group is missing the role assignement
