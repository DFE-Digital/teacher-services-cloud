# Azure GCP Workload Identity Federation

This allows Azure AKS client to access GCP resources without the use of plain text API Keys, that are considered a security risk.

Workload Identity Federation requires configuration on both Azure and GCP.

## GCP Configuration

### Create a workload identity pool

GCloud bash script:

```
create-gcp-workload-identity-pool.sh
```

### Create a workload identity pool provider

GCloud bash script:

```
create-gcp-workload-identity-pool-provider.sh
```
