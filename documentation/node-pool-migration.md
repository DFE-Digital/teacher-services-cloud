# Migrating Workloads to a New Node Pool

From time to time it may be necessary to increase the size of the VM's that a node pool is using or to add additional node pools with different VM sizes. This guide goes through some of the process and also things to watch out for.

## Add a new node pool

Add a new section to the `environment.tfvars.json` in `cluster/terraform_aks_cluster/config` e.g:

```
    "apps2": {
      "min_count": 3,
      "max_count": 20,
      "vm_size": "Standard_E4ads_v5",
      "max_surge": 1,
      "drain_timeout_in_minutes": 15,
      "node_soak_duration_in_minutes": 5,
      "node_labels": {
        "teacherservices.cloud/node_pool": "applications"
      }
    }
```

## Node Pool Upgrade Settings Guidelines
there are 3 settings:-

| Setting Name                  | Purpose                    | Factors Determining Tuning |
|-------------------------------|----------------------------|----------------------------|
| max_surge                     | Extra nodes during upgrade to assist with wokload migration| 1) Node pool size<br>  2) subnet IP headroom<br> 3) PDB strictness<br> 4) autoscaler<br> 5) capacity headroom |
| drain_timeout_in_minutes      | Max time to complete node drain | 1) Max termination grace<br> 2) pod startup time<br> 3) PDB strictness<br> 4) replicas<br> 5) scheduling/image pull speed |
| node_soak_duration_in_minutes | Pause between node upgrades | 1) Pod/daemonset startup time<br> 2) ingress stabilisation<br> 3) workload criticality<br> 4) pool size<br> risk appetite |

<br>

## Upgrade
Run a plan against the environment using `make environment terraform-plan` and confirm the addition of the new node (apps2), and that there are no unexpected removals.

If the changes in the plan are satisfactory, run `make environment terraform-apply` to run the plan and then confirm by typing `yes` at the prompt.

## Migrating the workloads

To migrate the workloads to the new node pool (e.g. from apps1 to apps2), first ensure the sizing is set appropriately if it is obviously different. Manual scaling can be used for this initially.

1. To ensure Kubernetes does not try to schedule existing workloads on new instances in the existing (apps1) node pool (because perhaps the new node pool doesn't have enough instances) disable the cluster auto-scaler `make environment disable-cluster-node-autoscaler NODE_POOL=apps1`.

2. Cordon the nodes in the existing (apps1) node pool to ensure no new workloads are scheduled on them. `make environment cordon-node-pool NODE_POOL=apps1`.

3. Drain the existing (apps1) node pool `make environment drain-node-pool NODE_POOL=apps1` to evict the existing pods from the existing (apps1) node pool. As long as the existing workloads can be scheduled on the new (apps2) node pool Kubernetes will create them there.

- Use commands like `kubectl -n namespace get pods -o=wide` to see the pods drain from the existing (apps1) node pool and get scheduled on the new one (apps2).

- If the pods are not being created on the new node pool as expected then:

    - The pod disruption budget is important here as it will ensure that there are always a number of instances of the existing workloads available to service requests while they are drained from the existing (apps1) node pool and scheduled on the new one (apps2). Check for these with `kubectl get pdb -A`.

    - Ensure the subscription has enough quota if auto-scaling is not working as expected and pods which are drained from one node pool are not being created on the new node pool.

    - Check the new node pool meets the node selector criteria for the work loads. In this example the new node pool will have a node label `"teacherservices.cloud/node_pool": "applications"` and the node selector for workloads will match this.

4. Once the workloads have been drained from the existing (apps1) node pool confirm that they are all in a `Running` state on the new (apps2) not pool using `kubectl -n namespace get pods -o=wide`.

5. Remove the (apps1) node pool configuration from the environments tfvars file and confirm the it will be the only node pool removed using `make environment terraform-plan`. Commit the change to a new branch, push it to GitHub, raise a pull request and merge the change to main.

6. Follow the workflow deployment on GitHub to ensure it completes successfully.
