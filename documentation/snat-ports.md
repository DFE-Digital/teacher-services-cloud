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

`NOTE: In case the number of VMs change then the quota of ports allocated need to changed according to the formula above.`

Outbound connections will fail when port exhaustion occurs

## Monitoring

Monitoring is enabled for high port usage and port exhaustion.

Link - https://github.com/DFE-Digital/teacher-services-cloud/blob/main/documentation/monitoring.md

## Useful Links

- https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections
