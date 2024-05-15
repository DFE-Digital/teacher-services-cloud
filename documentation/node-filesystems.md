# Node filesystems

Overview of node and container filesystems

## Details

Each node has a single ~125GB root filesystem mounted at /

In a containerized environment, containers should run with their own filesystems.
For AKS they utilize a snapshot overlay filesystem so containers can make changes while the container is running but share a base filesystem with other containers on the same node.

This overlay merges various directories into a single view on a designated mountpoint.
It requires three directories for creation: ‘lowerdir’, ‘upperdir’, and ‘workdir’
- lowerdir is designated for read-only access i.e. the base layer.
- upperdir is the directory where all modifications are stored i.e. the writable layer.
- workdir is used for processing changes before they are finalized in the upperdir and it is not included in the unified view.

This method saves a significant amount of diskspace, but means each containers view of space used/available is exactly the same.
For that reason we only monitor diskspace on the node root filesystem.

## Node garbage collection

AKS nodes keep unused containers and images. Kubelet garbage collection performs cleanup based on various settings.
- For concepts see https://kubernetes.io/docs/concepts/architecture/garbage-collection/#containers-images
- AKS settings and customisation https://learn.microsoft.com/en-us/azure/aks/custom-node-configuration?tabs=linux-node-pools

Current config can be viewed via
`kubectl get --raw "/api/v1/nodes/${nodename}/proxy/configz"|jq`

```
"imageGCHighThresholdPercent": 85,
"imageGCLowThresholdPercent": 80,
"evictionHard": {
      "memory.available": "750Mi",
      "nodefs.available": "10%",
      "nodefs.inodesFree": "5%",
      "pid.available": "2000"
    },
"maxPods": 110,
```


The kubelet considers the following disk usage limits when making garbage collection decisions:
```
"imageGCHighThresholdPercent": 85,
"imageGCLowThresholdPercent": 80,
```
Disk usage above the configured HighThresholdPercent value triggers garbage collection, which deletes images in order based on the last time they were used, starting with the oldest first. The kubelet deletes images until disk usage reaches the LowThresholdPercent value.

evictionHard: The kubelet will evict Pods under one of the following conditions:
- When the node's available memory drops below 750Mi.
- When the node's main filesystem's available space is less than 10%.
- When more than 95% of the node's main filesystem's inodes are in use.

So currently our nodes will
- keep old images up to 85% disk usage.
- will evict pods above 90%
Disk space monitoring using prometheus will alert at 87.5% usage.

## Disk usage troubleshooting

K8s/AKS recommendation is to not delete anything manually, but let garbage collection maintain containers and images.

These commands may be useful if there is a need to identify which containers/images are using the most diskspace.
```
# requires connecting to a priviliged container.
kubectl debug node/${nodename} -it --image=mcr.microsoft.com/cbl-mariner/busybox:2.0
chroot /host

# show tool options
crictl --help

# show disk usage for running pods
crictl stats

# show disk usage for all pods (incl not running)
crictl stats --all

# list images
crictl images
```
