# Low Priority application

The lowpriority-app deployment reserves cpu and memory on each node, which will be preempted by any standard deployment when there is no immediately available space.

The lowpriority-app will then be redeployed when new nodes have been added by the cluster autoscaler.

This should lessen the number of deployments that fail waiting for new nodes to be started when there is no immediately available capacity.

## Technical Details

Application deployment pods have no priority class with default priority 0.

So we create a lowpriority class with priority -1.

Then deploy a lowpriority app that uses this class.

This lowpriority app will reserve cpu/memory and will be preempted when another app needs capacity

and there is no immediately available resources

https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#how-to-use-priority-and-preemption

## To enable for a cluster

In ${cluster-env}.tfvars.json

- set "enable_lowpri_app": true
- override defaults if required (see below)
```
variable "lowpriority_app_cpu" { default = "1" }
```
This should match the cpu request value for a cluster

```
variable "lowpriority_app_mem" { default = "1500Mi" }
```
This should at least equal the max_memory of the largest service on that cluster

```
variable "lowpriority_app_replicas" { default = 3 }
```
We use 3 availability zones, so the default reserves space in each az.
This can be increased if deployments continue to be affected by insufficient capacity.

## Temporary reservation increase

There may be times when you need to temporarily increase the amount of reserved space,

e.g. scheduled increase in replicas for a service

in this case, you can simply scale the number of replicas of the lowpriority app.

```kubectl -n infra scale deployment/lowpriority-app --replicas n```
where n is the number of replicas required

Reset back to the default when the increase is no longer required.
