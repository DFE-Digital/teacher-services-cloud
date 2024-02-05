# Production checklist

For the service to be ready for end users, it must be reliable, performant and sustainable.

## StatusCake
This is the most essential monitoring as if it alerts, it means users cannot access the site. It monitors both [uptime](https://www.statuscake.com/features/uptime/) and [SSL certificate](https://www.statuscake.com/features/ssl/). Use the [terraform module](https://github.com/DFE-Digital/terraform-modules/blob/main/monitoring/statuscake/README.md) to configure it.

## Multiple replicas
By default the template deploys only 1 replica for each [kubernetes deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/). This is not sufficient for production as if the container is unavailable, there is no other replica to serve the requests. It may be unavailable because of high usage or simply because the cluster is moving the container to another node. This will happen when the cluster version is updated.

Use at least 2 [replicas](https://github.com/DFE-Digital/terraform-modules/blob/04895b849cd5124e615b4e6b1850c0d918d4d081/aks/application/variables.tf#L32) or as many as required by [performance testing](#performance-testing).

## Database plan
The template deploys a default plan for [postgres](https://github.com/DFE-Digital/terraform-modules/blob/83801213853ed1e4b4bdcb8d36773c8683ff010f/aks/postgres/variables.tf#L82) and [redis](https://github.com/DFE-Digital/terraform-modules/blob/83801213853ed1e4b4bdcb8d36773c8683ff010f/aks/redis/variables.tf#L63-L71).

It may be sufficient for the test environments, but it may not offer enough CPU, memory or network bandwidth for production. [Performance testing](#performance-testing) will help determine the right plans.

Note that for redis, all `azure_family`, `azure_sku_name` and `azure_capacity` must be changed jointly. Check [terraform postgres documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) for the allowed values.

## High availability
Each Azure region provides multiple [availability zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview). The kubernetes cluster is deployed across 3 zones so in case one is failing, the workload continues on the 2 others.

The same should be applied to database clusters. For postgres, set `azure_enable_high_availability` to true. For redis, use a Premium plan.

Note the cost is doubled for postgres, and [much higher](https://azure.microsoft.com/en-gb/pricing/details/cache/) for redis, so this should be used carefully.

## Performance testing
Simulate load from user traffic to determine the right number of instances and the database plan. This should cover the most typical user journeys. We recommend [K6](https://k6.io/) as it can be deployed to the cluster to minimise latency. Check the example in [teacher pay calculator](https://github.com/DFE-Digital/teacher-pay-calculator/tree/main/load_testing).

If time is short or user traffic is expected to be low, make sure to monitor the application and database usage after launch, and everytime there is a new significant feature. And be ready to scale up.

## Postgres backups to Azure storage
Azure postgres provides an [automatic backup](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-backup-restore) with a 7 days retention period. It can be restored from a point in time to a new database server.

In case there is a major  and the above doesn't work, we strongly suggest taking another daily backup every night and storing it in Azure storage. Set [azure_maintenance_window variable](https://github.com/DFE-Digital/terraform-modules/blob/83801213853ed1e4b4bdcb8d36773c8683ff010f/aks/postgres/variables.tf#L132) to true to create the storage. Then create a workflow such as [this example](https://github.com/DFE-Digital/early-careers-framework/blob/main/.github/actions/backup-and-upload-database/action.yml).

## Postgres and redis monitoring
Set `azure_enable_monitoring` to true to enable logging, monitoring and alerting. It will alert the infrastructure team by email by default.

## Front door monitoring
Set `azure_enable_monitoring` to true in the domains/infrastructure module to enable logging on front door. It is  verbose and costly and should not be used by default. But it can be extremely useful for troubleshooting.

## Custom domain
The default web application domain in production is `teacherservices.cloud`, and the application domain is `<application_name>.teacherservices.cloud`. It should not be used by end users. Rather we normally create a subdomain of either `education.gov.uk` or `service.gov.uk`. Here is the process:

- Create the domains infrastructure ([Azure DNS](https://learn.microsoft.com/en-us/azure/dns/dns-overview) and [Azure front door](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview)) in the production subscription, using the [domains/infrastructure module](https://github.com/DFE-Digital/terraform-modules/tree/main/domains/infrastructure)
- Delegate the DNS zone from either `education.gov.uk` or `service.gov.uk`. This is described in the [technical guidance](https://technical-guidance.education.gov.uk/infrastructure/hosting/dns/).
- Create a custom domain for each environment using the [domain/environment_domains module](https://github.com/DFE-Digital/terraform-modules/tree/main/domains/environment_domains)

If an [apex domain](https://learn.microsoft.com/en-us/azure/frontdoor/apex-domain) is used, make sure to configure [StatusCake](#statuscake) SSL monitoring as the certificate must be regenerated manually every 180 days.

## Pin all versions
The infrastructure code should pin the versions of all components to avoid receiving different versions. The build must be predictable between environments and over time. We should upgrade versions frequently, but only when it is desired and fully tested.

Components with versions:

- Terraform (in application, domains infrastructure and environment_domains)
- Terraform providers (azure, kubernetes, StatusCake)
- Postgres
- Redis
- Terrafile binary
- Terrafile environment files: each one should point at either main, testing or stable according to the [terraform modules release process](https://github.com/DFE-Digital/terraform-modules/blob/main/README.md#references)

## Maintenance window
Azure applies patches and minor updates to postgres and redis. Since this may cause a minor disruption, use the `azure_maintenance_window` and `azure_patch_schedule` variables to set them to a convenient time.

Note the postgres patches will always be applied first to environments where the maintenance window is not set.

## Service offering
The new service template uses the default "Teacher services cloud" value for the *Product* tag. This tag is used to identify the service in the Azure finance reporting. Each service must [register a new service offering and product](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/SitePages/Create-a-service-offering.aspx) and replace "Teacher services cloud" with the right name so that Azure costs are allocated accordingly.
