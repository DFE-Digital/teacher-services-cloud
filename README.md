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

- create KV certificate CA
    - The CA API key was created in our digicert service account, and is kept in a secret in the prod TSC Domains KeyVault.
- generate cert within KV certificate

For a more detailed explanation see,
https://technical-guidance.education.gov.uk/infrastructure/security/ssl-certificates/#automatic-via-key-vault

Use the defaults from the above documentation, the following properties are specific to our environment:
- Certificate Name: <local.environment>-teacherservices-cloud
- Subject CN: *.<local.environment>.teacherservices.cloud
- DNS Names: 0

<local.environment> refers to the value defined in [variables.tf](cluster/terraform_kubernetes/variables.tf)

Once the certificate is created you will need to logon to Digicert as per the above docs.  The credentials to do this can be found in the prod TSC Domains KeyVault.

On cluster build, terraform will load the cert into a kubernetes secret,
and this will be set as the default-ssl-certificate in the nginx ingress.

Note that terraform requires the KV cert to be created in a specific format

i.e. "${var.environment}-${var.config}-teacherservices-cloud"

e.g. cluster99-development-teacherservices-cloud

## Cluster DNS zone configuration

There are two DNS zones for cluster DNS.

    - teacherservices.cloud (prod zone)
    - development.teacherservices.cloud (dev zone)

### Zone Build

```
make {dev/prod}-domain domain-infra-{plan/apply}
```

There is also an NS record for delegation from teacherservices.cloud to development.teacherservices.cloud,
which is created if delegation_name and delegation_ns are set in tscp.tfvars.json

If the development zone NS records are changed for any reason, then these variables must be updated manually,
and the prod zone updated.

The teacherservices.cloud domain is created in route53 and owned by infra-ops. So if the production zone NS records are changed for any reason, then contact infra-ops to update the domain.

## Links
- [AKS upgrade](documentation/aks-upgrade.md)
- [Node pool migration](documentation/node-pool-migration.md)
- [Retrieving Log Analytics Data with KQL for AKS Clusters](documentation/aks-logs.md)
- [Rebuild AKS cluster with zero downtime](documentation/rebuild-cluster.md)
