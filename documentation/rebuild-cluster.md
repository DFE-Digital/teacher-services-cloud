# Rebuild AKS cluster with zero downtime

From time to time it may be required to rebuild the whole AKS cluster, for instance enabling RBAC or implementing a network policy. The cluster was designed for stateless applications so we can move them to another cluster while we rebuild the main one. The process was automated in part so testing can be done at each step.

We first build a new cluster with the same configuration. It is in the same virtual network but in a new subnet. The same namsepaces and ingress controller are deployed. The same TLS certificate is served.

Then we use scripts to export the resources from each namespace from one cluster, then import into the other one. The traffic is moved to the new cluster by modifying the DNS domain. This allows stopping or rebuilding the first cluster. Once it is ready, the process is reversed.

## Preparation
- Install prerequisites:
    - [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
    - [jq](https://stedolan.github.io/jq/)
    - [kubectl krew](https://krew.sigs.k8s.io/docs/user-guide/setup/install/) and [kubectl-neat](https://github.com/itaysk/kubectl-neat)
- Inform the dev teams to stop making changes. This process should be done outsdide of business hours.
- Raise the required PIM requests
- Determine the *applications domain* of this cluster. e.g.:
    - production: `*.teacherservices.cloud`
    - test: `*.test.teacherservices.cloud`
    - development: `*.cluster3.development.teacherservices.cloud`
    - etc
- Remove the delete lock on the AKS Azure resource

## Clone cluster
Add or update the variables and apply:
- `cluster/terraform_aks_cluster/config/<config>.tfvars.json`:
    - `"clone_cluster": true`
    - `"enable_azure_RBAC_clone": true`
- `cluster/terraform_kubernetes/config/<config>.tfvars.json`:
    - `"clone_cluster": true`
    - `"enable_lowpriority_app_clone": true` (if enabled for main)
- Run: `make <config> terraform-apply`

## Export resources from main cluster
This will export deployments, servies, configmaps, secrets, ingresses to json files in the local `<config>` directory.
- Run: `make <config> export-aks-resources` e.g. `make production export-aks-resources`
- This should create a new directory `<environment>_export` (e.g. `production_export`) containing a json file for each namespace

## Import resources to the cloned cluster
- Run: `make <config> clone import-aks-resources` (e.g. `make production clone import-aks-resources`)
- Watch deployments and wait for them to come up

## Validate the webapps manually
Since the applications domain points to the main cluster, you won't be able to test the cloned cluster app unless the domain is updated. However, it is possible to update it on your local environment first.

- Get cloned cluster credentials: `make <config> clone get-cluster-credentials` (e.g. `make production clone get-cluster-credentials`)
- Get the cloned cluster ingress IP: `kubectl get services`
- Add the cloned cluster ingress IP for the applications domain (see [Preparation](#preparation)) to your [hosts file](https://en.wikipedia.org/wiki/Hosts_(file)) (see this simple [tutorial](https://www.nublue.co.uk/guides/edit-hosts-file/)). e.g.:

    ```
    51.52.53.54 webapplication123.test.teacherservices.cloud
    ```
- Validate webapps on the applications domain
- Restore your hosts file

## Route traffic to the cloned cluster
- Change the applications domain record (see [preparation](#preparation)) in the DNS zone manually
- Wait at least 5 min for TTL to expire

## Rebuild the first cluster
- Wait for traffic to stop on main cluster. You can now make changes on the main cluster without impacting users.
- Delete the non-system pod disruption budgets (check with `kubectl get pdb -A`)
- Delete the aks-systems-logs diagnostic setting from the main cluster under Monitoring -> Diagnostic settings
- Make the required code changes in terraform
- Update your local branch to ignore the app domain record change that was made earlier, otherwise it will reset to the main cluster IP
    - `cluster/terraform_kubernetes/config/dns.tf`:
        - Add `lifecycle { ignore_changes = [records] }` to the cluster_a_record
- Run terraform-plan to check the changes and make sure only the main cluter is updated. Most of the cloned configuration is referenced from the main cluster, so if the value changes on the main cluster, it would also impact the cloned cluster and force a rebuild, which would disrupt users. If it's the case, hardcode the original value temporarily for the cloned cluster. For instance, if you want to change the default node pool vm_size from "Standard_D2_v2", change the cloned cluster from:

    ```
    vm_size = azurerm_kubernetes_cluster.main.default_node_pool[0].vm_size
    ```

    to:

    ```
    vm_size = "Standard_D2_v2"
    ```
- Run terraform-apply to rebuild the main cluster
- Add the delete lock on the AKS Azure resource

## Import resources to the main cluster
- Run: `make <config> import-aks-resources` (e.g. `make production import-aks-resources`)
- Watch deployments and wait for them to come up

## Validate the webapps manually
- Get main cluster credentials: `make <config> get-cluster-credentials` (e.g. `make production get-cluster-credentials`)
- Get the main cluster ingress IP: `kubectl get services`
- Add the main cluster ingress IP for the applications domain to your hosts file
- Validate webapps on the applications domain
- Restore your hosts file

## Route traffic to the main cluster
- Revert the local branch change to ignore the app domain record change that was made earlier
    - `cluster/terraform_kubernetes/config/dns.tf`:
        - Delete `lifecycle { ignore_changes = [records] }`from the cluster_a_record
- Run terraform-apply or change the applications domain record in the DNS zone manually
- Wait at least 5 min for the TTL to expire
- Update the DNS record in terraform code

## Delete the temp cluster
- `cluster/terraform_aks_cluster/config/<config>.tfvars.json`:
    - `"clone_cluster": false` (or remove variable)
    - `"enable_azure_RBAC_clone": false` (or remove variable)
- Run: `make <config> terraform-kubernetes-apply`
- `cluster/terraform_kubernetes/config/<config>.tfvars.json`:
    - `"clone_cluster": false` (or remove variable)
    - `"enable_lowpriority_app_clone": false` (or remove variable)
- Run: `make <config> terraform-aks-cluster-apply`. It may be necessary to remove the pod disruption budgets (check with `kubectl get pdb -A`).

## Delete the export files
The files contain application secrets and must be deleted
- `rm -rf <environment>_export` (e.g. `rm -rf production_export`)

## Commit changes
- Remove any temporary terraform code changes, such as hardcoded cloned cluster configuration
- If necessary, copy the main cluster terraform changes to the cloned cluster terraform code
- Run terraform-plan in all environments
- Commit the changes
