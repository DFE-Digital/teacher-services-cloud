# SNAT ports

## Overview

Source Network Address Translation (SNAT) allows network devices on a private network to connect to the public network. It is used to map private IP to a public IP address for outbound internet traffic.
This allows multiple devices to share a single public IP, thereby conserving public IP addresses and hides private IP addresses of internal devices from public network.
Azure cloud translates the source IP to an ephemeral IP address using SNAT. Ports are used for by all network traffic. During an outbound connection, **ephemeral port** is provided to the destination to maintain unique network traffic flow.
Each outbound connection has its own unique **ephemeral port**.
These ports on private network devices along with SNAT to communicate using public IPs are called SNAT ports.

## Port exhaustion

Each IP address provides 64,000 ports. If all the ports are used for an IP address, the outbound connections will fail, this is called **Port exhaustion**.

`NOTE: In Azure cloud, each VM is allocated 1024 SNAT ports by default.`

In case of Azure VMs, running behind a load balancer, SNAT ports are divided amongst the nodes. The formula for calculating max number of ports per VM
`Number of frontend IPs * 64K / Number of backend instances(including surge)`

### Considerations for calculating outbound ports and IPs
When calculating the number of outbound ports and IPs and setting the values, keep the following information in mind:
- The number of outbound ports per node is fixed based on the value you set.
- The value for outbound ports must be a multiple of 8.
- Adding more IP's lets you increase the available ports on all the nodes and/or increase nodes.
- You must account for nodes that might be added as part of upgrades, including the count of nodes specified via maxCount and maxSurge values.


`NOTE: In case the number of VMs change then the quota of ports allocated need to changed according to the formula above.`

Outbound connections will fail when port exhaustion occurs

Reference: [Configure the allocated outbound ports](https://learn.microsoft.com/en-us/azure/aks/configure-load-balancer-standard?tabs=create-cluster-ip-based%2Ccreate-cluster-managed-outbound-ips%2Ccreate-cluster-custom-ips%2Ccreate-cluster-custom-ip-prefixes%2Ccreate-cluster-outbound-ports-ips%2Ccreate-cluster-idle-timeout#configure-the-allocated-outbound-ports)

## Monitoring

Monitoring is enabled for high port usage and port exhaustion.

Link - https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/monitoring.md

## Useful Links

- https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections
