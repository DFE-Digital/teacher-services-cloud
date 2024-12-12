# AKS upgrade

AKS is continously updated and follows the Kubernetes release cycle. We must follow it as well to:

- Run a supported version
- Receive security updates
- Use new features
- Not add technical debt due to version incompatibilities

## Questions

### Which Kubernetes versions are supported by Microsoft?

*Kubernetes support policy*
Kubernetes follow a estimated three month update release cycle. Kubernetes will support each minor version for one year after release.

*Microsoft AKS version support*
Microsoft mirrors the Kubernetes support policy. Microsoft support the latest GA version alongside two previously released GA versions.

Microsoft follow the Azure Safe Deployment Practices [(SDP)](https://learn.microsoft.com/en-us/devops/operate/safe-deployment-practices). A release can take up to two weeks to roll out into all regions.

### How do I track the release cycle?

The [AKS Release Tracker](https://releases.aks.azure.com/webpage/index.html) should be monitored, this is useful to:
- View release notes
- Track specific features / fixes
- Data is updated real time
- View SDP rollout progress

The [Azure Update page](https://azure.microsoft.com/en-gb/updates/?category=containers) is another available feed.

### And Node OS Upgrades?
Microsoft release weekly updates to the Linux OS image. By default, a OS image update is carried each time the node pool is updated.

Currently, terraform will only update the node OS image when the AKS version is upgraded (See [GitHub issue](https://github.com/hashicorp/terraform-provider-azurerm/issues/20171)).
We should consider configuring node auto upgrade in the future.

## Version information

### Terraform
Each tfvars.json environment file contains:

- kubernetes_version
- default_node_pool orchestrator version
- each node pool orchestrator version

### Show cluster kubernetes version

```
az aks show --resource-group <ResourceGroup> --name <ClusterName> --query kubernetesVersion -o json
```

### Show orchestrator version on node pools

```
az aks nodepool list --resource-group <ResourceGroup> --cluster-name <ClusterName> --query "[].{Name:name,k8version:orchestratorVersion}" --output table
```

### Show available versions
To show available versions:

```
az aks get-versions --location uksouth --output table
```

To check available version for deployed cluster:

```
az aks get-upgrades --resource-group <ResourceGroup> --name <ClusterName> --output table
```

### Node image

Current image:
```
az aks nodepool show --resource-group <ResourceGroup> --cluster-name <ClusterName> --name <NodePoolName> --query nodeImageVersion
```

Available image:
```
az aks nodepool get-upgrades --resource-group <ResourceGroup> --cluster-name <ClusterName> --nodepool-name <NodePoolName>
```

## Upgrade process

1. Determine which is the next available version (see above)
1. Test the whole process in a dev cluster:
    - Deploy Apply to the cluster using `dev_platform_review_aks`
    - Continuously monitor it during the upgrade and check for downtime. Example:

        ```
        while true; do date; curl -is https://apply-review-1234.cluster4.development.teacherservices.cloud/check | grep HTTP ; sleep 1 ; done
        ```
    - Change kubernetes version, plan and apply
    - Change default node pool orchestrator version, plan and apply
    - Change application node pool orchestrator version, plan and apply
    - Run following commands in another terminal to see the cluster upgrade progress.
        -  kubectl get events --watch
        -  kubectl get nodes --watch
    - Align the version of kube-state-metrics with kubernetes version. See [compatibility matrix](https://github.com/kubernetes/kube-state-metrics?tab=readme-ov-file#compatibility-matrix)
1. After successful upgrades for each environment, check metrics are still displaying and working well in Grafana
    - Check the dashboards in grafana: https://grafana.cluster<x\>.development.teacherservices.cloud, https://grafana.platform-test.teacherservices.cloud, https://grafana.test.teacherservices.cloud, https://grafana.teacherservices.cloud
1. Follow the same manual process to upgrade the platform_test cluster
    - Test with the welcome app: https://www.platform-test.teacherservices.cloud/
    - Raise PR
    - Wait 24h
1. Follow the same manual process to upgrade the test cluster
    - Test with the welcome app: https://www.test.teacherservices.cloud/
    - Raise PR
    - Wait 24h
1. Follow the same manual process to upgrade the production cluster
    - Test with the welcome app: https://www.teacherservices.cloud/
    - Raise PR

1. Update the kubectl client version to match the AKS (Azure Kubernetes Service) cluster version in GitHub Actions.
    - You can achieve this using the set-kubectl action from the https://github.com/DFE-Digital/github-actions/set-kubectl


## Troubleshooting

1. If you see any failures , Login Azure portal and Go to AKS Cluster.
2. Click on Activiy Log on left hand pannel , it lists all events , check failure events , it will give the failure reason.
3. If the failure message contains like this "Eviction failed with Too many Requests error. This is often caused by a restrictive Pod Disruption Budget (PDB) policy"
4. Delete the PDB policy and then run following azure cli to resume upgrade.
       -  az aks nodepool upgrade --cluster-name cluster-name -g resource-group -n node-pool-name -k aks-version
5. Check Node Status Regularly.
      1. Regularly monitor the status of nodes in your Kubernetes cluster. If a node is stuck in 'Ready,SchedulingDisabled' state, follow these steps.
      2. Describe the Node :
            1. Use the following command to describe the node and understand the reason for the status:
                1.  ``` kubectl describe node <node-name>  ```
                2. Look for reasons in the output. For  example, you might see :
                                  - ``` Eviction blocked by Too many Requests (usually a pdb): claim-additional-payments-for-teaching-production-worker-64dqxw ```.
     3. Check the Pod Status
         1. Identify the problematic pod mentioned in the node description. Check its status using:
               1.  ``` kubectl get pods -n <namespace> | grep <pod-name>  ```
                   1. Example : ``` srtl-production        claim-additional-payments-for-teaching-production-worker-64dqxw   0/1     CrashLoopBackOff ```.
      4. Handle Pods in CrashLoopBackOff State:
         1. If the pod is in a ``` CrashLoopBackOff ``` state, it might be preventing the node from scheduling new pods
         2. Scale down the problematic pod to resolve the issue. For example, if it is part of a deployment, you can scale down the deployment
         3.  ``` kubectl scale deployment <deployment-name> --replicas=0 -n <namespace>  ```
