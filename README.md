# Teacher Services Cloud

A repo for building Teacher Sevices cloud infrastructure

## Directory Layout

```
-> cluster
    -> config
        *.sh files for each cluster environment
    -> terraform
        *.tf files for cluster build
        -> config
            *.json files for each cluster environment
-> custom_domains
    -> config
        *.sh for each cluster DNS zone
    -> terraform
        -> infrastructure
            *.tf files for cluster DNS zone build
            -> workspace_variables
                *.tfvars, *.json for each cluster DNS zone
Makefile
```

## Cluster Configuration

### Cluster Build

Development

```
make development terraform-{plan/apply} ENVIRONMENT=cluster{n}
```

where n = 1-6

e.g.
```
make development terraform-plan ENVIRONMENT=cluster1
```

Test

```
make test terraform-{plan/apply} ENVIRONMENT=cluster{n}
```

where n = 1-6

e.g.
```
make test terraform-plan ENVIRONMENT=cluster1
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
    - The CA API key was created in our digicert service account, and is kept in a prod KV secret.
- generate cert within KV certificate

For a more detailed explanation see,
https://technical-guidance.education.gov.uk/infrastructure/security/ssl-certificates/#automatic-via-key-vault

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
