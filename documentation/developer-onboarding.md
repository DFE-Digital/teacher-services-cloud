## Developer onboarding

**How to request access to s189?**

**What are the test and production clusters?**

**How to request and approve PIM?**

**How to get cluster credentials?**

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

**You will need PIM to perform below actions**

- To get deployments in test cluster you can use `kubectl get deployments --all-namespaces` this return all namespaces in the current cluster like below. If you havent done it already get your credentials to test cluster using `make test get-cluster-credentials CONFIRM_TEST=yes` this will set your cluster context as well.
-
