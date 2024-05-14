# Teacher Services Cloud

A repo for building Teacher Sevices cloud infrastructure

## Directory Layout

```
- cluster
    - config
        *.sh config files for each cluster environment
    - terraform_aks_cluster
        *.tf files for low level cluster set-up
        - config
            *_backend.tfvars and *.tfvars.json config files for each cluster environment
    - terraform_kubernetes
        *.tf files for high-level configuration using the kubernetes and helm providers only
        - config
            *_backend.tfvars and *.tfvars.json config files for each cluster environment
- custom_domains
    - config
        *.sh config files for each cluster DNS zone
    - terraform
        - infrastructure
            *.tf files for cluster DNS zone build
            - workspace_variables
                *_backend.tfvars and *.tfvars.json config files for each cluster DNS zone
Makefile
```

## Cluster Configuration

### Cluster Build

#### Development environments: cluster1, cluster2...

```
make development terraform-{plan/apply} ENVIRONMENT=cluster{n}
```

where n = 1-6

e.g.
```
make development terraform-plan ENVIRONMENT=cluster1
```

#### Permanent environments: platform-test, test, production

```
make <environment> terraform-{plan/apply} CONFIRM...
```

e.g.
```
make test terraform-plan CONFIRM_TEST=yes
```

### Initial set-up
When creating a brand new cluster with its own configuration, follow these steps:
- Create the config files in:
    - cluster/config
    - cluster/terraform_aks_cluster/config
    - cluster/terraform_kubernetes/config
- Create the new config entry in the Makefile
- Create low-level terraform resources: `make <config> validate-azure-resources` and `make <config> deploy-azure-resources`
- Request the Cloud Engineering Team to assign role "Network Contributor" to the new managed identity on the new resource group
- Create the admin AD group following the [AD groups documentation](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/SitePages/AKS%20AD%20groups.aspx)
- Use the group object id in the admin_group_id variable
- Use PIM for groups to activate membership of the admin group
- Run: `make <environment> terraform-apply`
- Configure a domain pointing at the new ingress IP following [Cluster DNS zone configuration](#cluster-dns-zone-configuration).
- Create or update the user AD groups as per the [AD groups documentation](https://educationgovuk.sharepoint.com/sites/teacher-services-infrastructure/SitePages/AKS%20AD%20groups.aspx)

### kubectl
- Follow the [kubectl documentation](https://kubernetes.io/docs/tasks/tools/#kubectl) to install it
- Configure the credentials using the `get-cluster-credentials` make command. Example:

```
make platform-test get-cluster-credentials
make development get-cluster-credentials ENVIRONMENT=cluster1
```

### DNS records

We use a wildcard DNS record for the default domain of any application deployed to the cluster.

For the development clusters, on cluster build this record will be automatically created in the dev DNS zone.
This occurs if cluster_dns_zone is set in the cluster config tfvars.json for that environment.

### Cluster TLS

We use a wildcard certificate for the default domain of any application deployed to the cluster.

Certs are created from Azure Keyvault (manually),
and then loaded into the cluster using terraform on cluster build.

Initial set up requires manual steps in the cluster Azure KV.

#### Add new top domain
The following steps were required for allowing teacherservices.cloud top domain. They won't be required for new clusters under the same top domain

##### Generate value for DNS record

1. Login to GlobalSign with a Service Account
1. Select Managed SSL -> Select Add Domain
1. Enter ‘teacherservices.cloud’
1. Add point of contact (a senior Civil Servant)
1. Select DNS Verification (on next page)

The feedback should look something like:

>Thank you for submitting your application. Your order number is DSMS20003575933.
Domain: teacherservices.cloud
The DNS value for this domain is:
XXXXXXXXXXX=XXXXXXXXXXXXXXXXXX

##### Add generated value to DNS zone

1. Go to DNS Zone in Azure and then select teacherservices.cloud
1. Create or update a record named @, with type TXT, setting the value to to the value generated in Globalsign (or add as an additional value, if it had a value already)

##### Verify Domain

1. Select ‘Manage Domains’ in GlobalSign
1. Search for teacherservices.cloud and select the green check mark
1. Select verify domain
1. You should receive a feedback [Your domain has been successfully verified.]

##### Create Certificate in Azure

Ensure CAA record (for teacherservices.cloud) allows GlobalSign, if not, add it following the pattern:

```
Flags = 0, Tag = issue, value =“globalsign.com”
```

See [terraform configuration](https://github.com/DFE-Digital/terraform-modules/blob/main/dns/zones/resources.tf) or [GlobalSign documentation](https://support.globalsign.com/ssl/general-ssl/how-add-dns-caa-record-dns-zone-file).

1. Navigate to Key Vaults, select the applicable Key vault
1. Either create a new certificate or generate a new version of an existing certificate(the latter is preferred where possible) - Validity is typically left at 12 months
1. Add caa record list and configuration as shown in https://github.com/DFE-Digital/terraform-modules/blob/main/dns/zones/resources.tf

For a more detailed explanation see,
https://technical-guidance.education.gov.uk/infrastructure/security/ssl-certificates/#automatic-via-key-vault

Use the defaults from the above documentation, the following properties are specific to our environment:
- Certificate Name: <local.environment>-teacherservices-cloud
- Subject CN: *.<local.environment>.teacherservices.cloud
- DNS Names: 0
- Add the certificate name to the [terraform configuration](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/config/test.tfvars.json#L20) with the [variable](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/cluster/terraform_kubernetes/variables.tf#L22)

<local.environment> refers to the value defined in [variables.tf](cluster/terraform_kubernetes/variables.tf)

On cluster build, terraform will load the cert into a kubernetes secret,
and this will be set as the default-ssl-certificate in the nginx ingress.

Note that terraform requires the KV cert to be created in a specific format

i.e. `${var.environment}-${var.config}-teacherservices-cloud`

e.g. cluster99-development-teacherservices-cloud

## Cluster DNS zone configuration

There are two DNS zones for cluster DNS:

- teacherservices.cloud (prod zone)
- development.teacherservices.cloud (dev zone)

### Zone Build

```
make {dev/prod}-domain domains-infra-{plan/apply}
```

There is also an NS record for delegation from teacherservices.cloud to development.teacherservices.cloud,
which is created if delegation_name and delegation_ns are set in tscp.tfvars.json

If the development zone NS records are changed for any reason, then these variables must be updated manually,
and the prod zone updated.

The teacherservices.cloud domain is created in route53 and owned by infra-ops. So if the production zone NS records are changed for any reason, then contact infra-ops to update the domain.

## Links
### External
- [Developer onboarding](documentation/developer-onboarding.md)
- [Onboard a new service to AKS](documentation/onboard-service.md)
- [Onboarding form template](documentation/onboard-form-template.md)
- [Kubernetes cluster Public IPs](documentation/public-ips.md)
- [Production checklist](documentation/production-checklist.md)
- [Maintenance page](documentation/maintenance-page.md)
- [Postgres FAQ](documentation/postgres-faq.md)
- [Cluster plublic IPs](documentation/public-ips.md)

### Internal
- [AKS upgrade](documentation/aks-upgrade.md)
- [Node pool migration](documentation/node-pool-migration.md)
- [Rebuild AKS cluster with zero downtime](documentation/rebuild-cluster.md)
- [Ingress controller upgrade](documentation/Ingress-controller-upgrade.md)
- [Retrieving Log Analytics Data with KQL for AKS Clusters](documentation/aks-logs.md)
- [Shipping application logs to Logit.io](/documentation/logit-io.md)
- [Low priority app](documentation/lowpriority-app.md)
- [Monitoring](documentation/monitoring.md)
- [Slack webhook integration](documentation/slack-webhook-integration.md)
- [Azure GCP Workload Identity Federation](documentation/azure-gcp-workload-identity-federation.md)
