# Production checklist

For the service to be ready for end users, it must be reliable, performant and sustainable.

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

In case there is a major issue and the above doesn't work, we strongly suggest taking another daily backup every night and storing it in Azure storage. Set [azure_enable_backup_storage variable](https://github.com/DFE-Digital/terraform-modules/blob/83801213853ed1e4b4bdcb8d36773c8683ff010f/aks/postgres/variables.tf#L132) to true to create the storage account. Then create a workflow using the [backup-postgres](https://github.com/DFE-Digital/github-actions/tree/master/backup-postgres) github action and [schedule](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule) it nightly.

## Logging
Container logs are available temporarily in the cluster. To store the logs, all applications should ship logs to Logit.io. The Teacher services UK account stores all the data in the UK region.

Set [enable_logit](https://github.com/DFE-Digital/terraform-modules/blob/eae51cf1b82b5eb5a4fe6cafd76d50c8469b4aad/aks/application/variables.tf#L151) to `true` to ship the logs. Logs must sent as json, normally using [the standard libraries](https://technical-guidance.education.gov.uk/infrastructure/monitoring/logit/) for the language.

Developers need to request [access to Logit.io](developer-onboarding.md#access) to visualise the logs.

## Monitoring
### StatusCake
[Statuscake](https://technical-guidance.education.gov.uk/infrastructure/monitoring/statuscake/) is the most essential monitoring tool as if it alerts, it means users cannot access the site. Use the [terraform module](https://github.com/DFE-Digital/terraform-modules/blob/main/monitoring/statuscake/README.md) to monitor:
- [uptime](https://www.statuscake.com/features/uptime/)
- [SSL certificate](https://www.statuscake.com/features/ssl/)
- [Push check](https://www.statuscake.com/kb/knowledge-base/what-is-push-monitoring/)

Ask the infra team for help with these steps:
- Create the dev team [contact group](https://app.statuscake.com/CurrentGroups.php) if necessary. Add the team email, developer emails and phone numbers if desired.
- Get the dev team contact group id from the URL
- Obtain an existing API key or request a new one. Ideally there should be one per service or at least one per area.
- Create a secret "STATUSCAKE-API-TOKEN" in the "inf" keyvault, with the API key as value. The statuscake provider is configured to get the token from `module.infrastructure_secrets.map.STATUSCAKE-API-TOKEN`.
- Fill in `enable_monitoring`, `external_url` and `statuscake_contact_groups` variables in the environment *tfvars.json* file. Example:
  ```json
  "enable_monitoring" : true,
  "external_url": "https://calculate-teacher-pay.education.gov.uk/healthcheck",
  "statuscake_contact_groups": [195955]
  ```
- For production, add the infra team contact group id: `282453`

### Upptime
We provide a [status page](https://teacher-services-status.education.gov.uk/) of all services in Teacher services. It uses [Github actions](https://github.com/DFE-Digital/teacher-services-upptime/actions) to ping websites running every 5 min (more or less) and produce a dashboard for external users.

When a website is offline, it shows the error in the daashboard, sends an alert to the infra Slack channel and records an incident as a [Github issue](https://github.com/DFE-Digital/teacher-services-upptime/issues). The team can post comments to the issue to send incident updates.

Request write access to the repository and edit the [upptimerc.yml](https://github.com/DFE-Digital/teacher-services-upptime/blob/master/.upptimerc.yml) without PR to add your production website.

### Postgres and redis
We use *Azure monitor* to define alerts on postgres and redis metrics. Alerts are sent via email, using a [monitoring action group](https://github.com/DFE-Digital/terraform-modules/tree/main/aks/application#monitoring). The [new_service template](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/templates/new_service/Makefile) includes the `make action-group` command to automate this task. Ask the infra team to set it up. By default it is set up to alert the infrastructure team by default, but any email address or [distribution list](https://dfe.service-now.com.mcas.ms/ithelpcentre?id=sc_cat_item&table=sc_cat_item&sys_id=a28540a5dbeeee005ca2fddabf961968&recordUrl=com.glideapp.servicecatalog_cat_item_view.do) (preferred) may be used.

Set `azure_enable_monitoring` to true to enable logging, monitoring and alerting.

### Front door
Set `azure_enable_monitoring` to true in the domains/infrastructure module to enable logging on front door. It is  verbose and costly and should not be used by default (check with the infra team). But it can be extremely useful for troubleshooting.

### Pods
Pods CPU, memory, restarts... are monitored using prometheus. To enable it follow:
- [Enable prometheus scraping](https://github.com/DFE-Digital/terraform-modules/blob/main/aks/application/tfdocs.md#input_enable_prometheus_monitoring) on *each* deployment you want to monitor
- Create a webhook slack app in the [Teacher services cloud Slack app](https://api.slack.com/apps/A05Q1UNM3U2) or reuse one if it has the desired channel
- If using a new webhook, create a secret in the Teacher services cloud keyvault (*s189t01-tsc-ts-kv* or *s189p01-tsc-pd-kv*). It must be named *SLACK-WEBHOOK-XXX* where XXX is a service like ATT or an area like CPD.
- If using a new webhook, add the secret name to [alertmanager_slack_receiver_list](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/config)
- Enable alerting on *each* deployment you want to monitor by adding to [alertable_apps](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/config/), each entry is: `"namespace/deployment": { "receiver": "RECEIVER"}`, such as:
  ```json
  "bat-production/itt-mentor-services-sandbox": {
      "receiver": "SLACK_WEBHOOK_ITTMS"
    },
  ```
  If the receiver is not specified, SLACK_WEBHOOK_GENERIC will be used to alert the infra channel.

## Custom domain
The default web application domain in production is `teacherservices.cloud`, and the application domain is `<application_name>.teacherservices.cloud`. It should not be used by end users. Rather we normally create a subdomain of either `education.gov.uk` or `service.gov.uk`. Here is the process:

- Create the domains infrastructure ([Azure DNS](https://learn.microsoft.com/en-us/azure/dns/dns-overview) and [Azure front door](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview)) in the production subscription, using the [domains/infrastructure module](https://github.com/DFE-Digital/terraform-modules/tree/main/domains/infrastructure)
- Delegate the DNS zone from either `education.gov.uk` or `service.gov.uk`. This is described in the [technical guidance](https://technical-guidance.education.gov.uk/infrastructure/hosting/dns/).
- Create a custom domain for each environment using the [domain/environment_domains module](https://github.com/DFE-Digital/terraform-modules/tree/main/domains/environment_domains)

If an [apex domain](https://learn.microsoft.com/en-us/azure/frontdoor/apex-domain) is used, make sure to configure [StatusCake](#statuscake) SSL monitoring as the certificate must be regenerated manually every 180 days.

## Caching
The custom domains are implemented using the Azure front door CDN. It provides simple caching of HTTP requests by path. For instance, rails apps usually cache assets (javascripts, CSS, fonts...) under the `/assets` path.

CDN Caching makes requests faster for users and reduces the load on the application. Use the environment_domains module [cached_paths variable](https://github.com/DFE-Digital/teacher-services-cloud/blob/8b7a9e94e41747b5ac4faf9fc4b41632c3c741ac/templates/new_service/terraform/domains/environment_domains/config/production.tfvars.json#L9-L10) to cache all the paths as required.

## Redirects
It is possible to support multiple domains and subdomains, and create a redirect between them to catch more user traffic. For instance:
- https://www.apply-for-teacher-training.education.gov.uk/ redirects to https://www.apply-for-teacher-training.service.gov.uk/
- https://www.claim-funding-for-mentor-training.education.gov.uk redirects to https://claim-funding-for-mentor-training.education.gov.uk

Use the environment_domains module [redirect_rules variable](https://github.com/DFE-Digital/terraform-modules/blob/1d9f7202cb981499ed5a86bd4bdf655013a74743/domains/environment_domains/variables.tf#L46).

## Pin all versions
The infrastructure code should pin the versions of all components to avoid receiving different versions. The build must be predictable between environments and over time. We should upgrade versions frequently, but only when it is desired and fully tested.

Components with versions:

- Base docker image: pin language version (e.g. ruby 3.3.0) and Alpine version (e.g. alpine-3.20)
- Terraform (in application, domains infrastructure and environment_domains)
- Terraform providers (azure, kubernetes, StatusCake)
- Postgres
- Redis
- Terraform modules: the TERRAFORM_MODULES_TAG variable should point at either main, testing or stable according to the [terraform modules release process](https://github.com/DFE-Digital/terraform-modules/blob/main/README.md#references)

## Maintenance window
Azure applies patches and minor updates to postgres and redis. Since this may cause a minor disruption, use the `azure_maintenance_window` and `azure_patch_schedule` variables to set them to a convenient time, when the service receives less traffic.

Note the postgres patches will always be applied first to environments where the maintenance window is not set.

## Service offering
The new service template uses the default "Teacher services cloud" value for the *Product* tag. This tag is used to identify the service in the Azure finance reporting. Each service must [register a new service offering and product](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/SitePages/Create-a-service-offering.aspx) and replace "Teacher services cloud" with the right name so that Azure costs are allocated accordingly.

## Maintenance page
Optional but recommended for user facing services. See [Maintenance page](maintenance-page.md) for more details.

## Lock critical resources
Add a lock to critical Azure resources to prevent against accidental deletion, such as production databases. Members of the `s189-teacher-services-cloud-ResLock Admin` Entra ID group (infra team) can manage locks.
- Open the resource in the Azure portal
- Settings > Locks > + Add > Lock name: Delete, Lock type: Delete > OK

## Build image security scanning
We use SNYK scanning to [check build images for vulnerabilities](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/SitePages/Testing-software.aspx).

This is enabled by passing a valid [SNYK-TOKEN](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/templates/new_service/.github/workflows/build-and-deploy.yml#L3) to the build-and-deploy github action.

## Secrets
We keep application secrets in Azure key vault. There is always a risk of an attack or a mistake leading to a leak, especially when using public repositories. In case an incident happens, it is important to **rotate all the secrets** as soon as possible.

We want to minimise the time to recovery, and help the team members rotating the secrets, especially when they are not familiar with them. Secrets are not stored in the Github repository and don't have comments nor git commit history. We recommend keeping an exhaustive list of all secrets, preferably in Sharepoint and not in the public repository.

Document for each secret:
- Environment variable name
- What is it used for
- How to generate or request a new secret
