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
            *.tfvars.json config files for each cluster environment
    - terraform_kubernetes
        *.tf files for high-level configuration using the kubernetes and helm providers only
        - config
            *.tfvars.json config files for each cluster environment
- custom_domains
    - config
        *.sh config files for each cluster DNS zone
    - terraform
        - infrastructure
            *.tf files for cluster DNS zone build
            - config
                *.tfvars.json config files for each cluster DNS zone
Makefile
```

## Operation

### Prerequisites

- Request to be added to the admin AD groups
- Install [developer software](documentation/developer-onboarding.md#software-requirements)

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

### kubectl
Login to Azure and configure the credentials using the `get-cluster-credentials` make command before running kubectl

```
az login
make platform-test get-cluster-credentials
make development get-cluster-credentials ENVIRONMENT=cluster1
kubectl get pods
```

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
- [Disaster recovery](documentation/disaster-recovery.md)
- [Disaster recovery testing](documentation/disaster-recovery-testing.md)
- [HTTP request](documentation/http.md)

### Internal
- [Platform set-up](documentation/platform-set-up.md)
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
