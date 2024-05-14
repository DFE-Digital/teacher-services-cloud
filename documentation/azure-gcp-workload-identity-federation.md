# Azure GCP Workload Identity Federation

This allows Azure AKS client to access GCP resources without the use of plain text API Keys, that are considered a security risk.

Workload Identity Federation requires configuration on both Azure and GCP.

## GCP Configuration

To configure GCP run the gcloud scripts below.

### Pre-requisites for running gcloud scripts

- [Install the gcloud CLI](https://cloud.google.com/sdk/docs/install) for you operating system
- A google account is required. This can be requested from ServiceNow or contact the #twd_data_insights team on slack
- **Owner** permissions are required for the project to be configured. This can be requested from the #twd_data_insights team on slack
- Authenticate with gcloud on the cli to run the scripts below

### Authenticating with gcloud

Login with the following gcloud command to authenticate through a browser:

```
gcloud auth login
```

For convenience to set defaults run the init command and follow the prompts:

```
gcloud init
```

### Create a workload identity pool

gcloud shell script:

```
scripts/azure-gcp-wif/create-gcp-workload-identity-pool.sh
```

### Create a workload identity pool provider

gcloud shell script:

```
scripts/azure-gcp-wif/create-gcp-workload-identity-pool-provider.sh
```
