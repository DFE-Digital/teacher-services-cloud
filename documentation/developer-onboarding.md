## Developer onboarding

**How to request access to s189?**


- There are 3 s189 subscriptions, one for each environment (dev, test and prod)

  `s189-teacher-services-cloud-development`

  `s189-teacher-services-cloud-test`

  `s189-teacher-services-cloud-production`

- There is an assumption that you have been given a cip account
- You can then request access to the S189 subscription by contacting the Teacher Services Infrastructure team

**How to request and approve PIM?**
- Once added to the s189 subscription, you can PIM yourself to the test subscription
- You can request PIM to production subscription however this will need to be approved.
- You can approve PIM requests to production subscription by going to Privileged Identity Management (PIM) in Azure portal and selecting Approve request - Azure resources select the user and approve the request.
- For detailed instruction on how to request and approve PIM please refer to [tech guidance](https://technical-guidance.education.gov.uk/infrastructure/hosting/azure-cip/#onboarding-users)


**What are the test and production clusters?**

**Development cluster**

- `s189-teacher-services-cloud-development`: Developement subscription is where you can deploy your own dev cluster and apps test your changes before merging to main branch.

**Test cluster**
- The test clusters are hosted in the `s189-teacher-services-cloud-test` subscription.
- The test cluster is used for testing and development which is in `s189-teacher-services-cloud-test` subscription
  1. `s189t01-tsc-test-aks` (test cluster) in `s189t01-tsc-ts-rg` (resource group)

**Production cluster**
- The production cluster is used for production which is in `s189-teacher-services-cloud-production` subscription
  1. `s189p01-tsc-production-aks` (prod cluster) in `s189p01-tsc-pd-rg` (resource group)
sudo

**How to get cluster credentials?**

- You can get test cluster credentials by running `make test get-cluster-credentials CONFIRM_TEST=yes` this will set your cluster context as well.
- For more information on how to get cluster credentials please refer to [new service template](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/templates/new_service/Makefile#L112)

**What is a namespace and how are they laid out on test and prod clusters**
- Namespaces are a way to logically partition and isolate resources within a Kubernetes cluster. Each namespace has its own set of isolated resources like pods, services, deployments etc.
- By default, a Kubernetes cluster will have a few initial namespaces created like "default", "kube-system", "kube-public" etc.
- Namespaces provide a scope for names, so resources in different namespaces can have the same name but be differentiated by their namespace.
- Namespaces are managed by the Kubernetes API server, and any namespaced resource has a namespace field as part of its object metadata.
- Resources like nodes and persistentVolumes are cluster-scoped and not part of any namespace.
- Namespaces provide authorization and access control scopes, so you can use things like RBAC roles and bindings scoped to a particular namespace.
- Limit ranges and resource quotas can be defined per-namespace as well to restrict resource usage and control allocation.
Each namespace has its own isolated view of the cluster state although they share a single physical cluster.

**Basic commands: deployments, pods, top pods, describe, logs (app and ingress)**

*You will need PIM to perform below actions in test and production*

 *`deployment`*: is a Kubernetes object that allows you to specify the desired state of your application. It allows you to deploy multiple pods and services and manage them as a single entity. It also allows you to do rolling updates and rollbacks.

Examples kubectl deployment usage:

    kubectl get deployments -n <namespace>
    kubectl get deployments --all-namespaces
    kubectl describe deployment <deployment-name>
    kubectl rollout status deployment <deployment-name>
    kubectl rollout history deployment <deployment-name>
    kubectl rollout undo deployment <deployment-name>
    kubectl scale deployment <deployment-name> --replicas=3


 *`pods`*: are ephemeral and can be deleted or recreated at any time. Deployments provide a way to keep pods running and provide a way to update them when needed.

 Examples kubectl pod usage:

    kubectl get pode -n <namespace>
    kubectl describe pod <pod-name> -n <namespace>
    kubectl logs <pod-name> -n <namespace>
    kubectl logs <pod-name> -n <namespace> -c <container-name>
    kubectl get pod <pod-name> -n <namespace> -w

 *`top pods`*: `kubectl top pods` displays the CPU and memory usage of the pods in the current namespace. If you want to see the usage of pods in a specific namespace, you can use the -n flag.

 Examples kubectl top pod usage:

    kubectl top pods
    kubectl top pods -n <namespace>

 *`describe`*:  `kubectl describe` displays detailed information about a Kubernetes resource. It can be used to get information about pods, deployments, services, nodes, etc.

 Examples kubectl describe usage:

    kubectl describe pod <pod-name> -n <namespace>
    kubectl describe deployment <deployment-name> -n <namespace>
    kubectl describe service <service-name> -n <namespace>
    kubectl describe node <node-name> -n <namespace>

*`logs`*: `kubectl logs` displays the logs of a pod. By default, it prints the logs of the first container in the pod. If you want to print the logs of a specific container, you can use the -c flag.

 Examples kubectl logs usage:

    kubectl logs <pod-name> -n <namespace>
    kubectl logs <pod-name> -n <namespace> -c <container-name>
