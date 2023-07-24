## Developer onboarding

**How to request access to s189?**


- There are 3 s189 subscriptions, one for each environment (dev, test and prod)

  `s189-teacher-services-cloud-development`

  `s189-teacher-services-cloud-test`

  `s189-teacher-services-cloud-production`


- There is an assumption that you have have been given a cip account
- You can then request access to the S189 subscription by contacting the Teacher Services Infrastructure team


**What are the test and production clusters?**

**Test cluster**
- The test and production clusters are hosted in the s189 subscription
- The test cluster is used for testing and development which is in `s189-teacher-services-cloud-test` subscription
  1. `s189t01-tsc-test-aks` (test cluster) in `s189t01-tsc-ts-rg` (resource group)

  2. `s189t01-tsc-platform-test-aks` (platform test cluster) in `s189t01-tsc-pt-rg` (resource group)

**Production cluster**
- The production cluster is used for production which is in `s189-teacher-services-cloud-production` subscription
  1. `s189p01-tsc-production-aks` (prod cluster) in `s189p01-tsc-pd-rg` (resource group)


**How to request and approve PIM?**
- Once added to the s189 subscription, you can PIM yourself to the test subscription
- You can request PIM to production subscription however this will need to be approved.
- You can approve PIM requests to production subscription by going to Privileged Identity Management (PIM) in Azure portal and selecting Approve request - Azure resources select the user and approve the request.
- For detailed instruction on how to request and approve PIM please refer to [tech guidance](https://technical-guidance.education.gov.uk/infrastructure/hosting/azure-cip/#onboarding-users)



**How to get cluster credentials?**

- You can get cluster credentials by running `make test get-cluster-credentials CONFIRM_TEST=yes` this will set your cluster context as well.
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

 *`Deployment`*: is a Kubernetes object that allows you to specify the desired state of your application. It allows you to deploy multiple pods and services and manage them as a single entity. It also allows you to do rolling updates and rollbacks.

 *`Pods`*: are ephemeral and can be deleted or recreated at any time. Deployments provide a way to keep pods running and provide a way to update them when needed.

 *Top pods*: `kubectl top pods` displays the CPU and memory usage of the pods in the current namespace. If you want to see the usage of pods in a specific namespace, you can use the -n flag.

*You will need PIM to perform below actions*

- To get deployments in test cluster you can use `kubectl get deployments --all-namespaces` this return all namespaces in the current cluster like below. If you havent done it already get your credentials to test cluster using `make test get-cluster-credentials CONFIRM_TEST=yes` this will set your cluster context as well.

- To get all pods in a namespace you can use `kubectl get pods -n <namespace>` this will return all pods in the namespace i.e. `kubectl get pods -n bat-qa` this will return all pods in bat-qa namespace.
- Top pods in a namespace `kubectl top pods -n <namespace>` i.e. `kubectl top pods -n bat-qa` this will return top pods in bat-qa namespace.
