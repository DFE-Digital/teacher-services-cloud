# Azure GCP Workload Identity Federation

This allows Azure AKS client to access GCP resources without the use of plain text API Keys, that are considered a security risk.

Workload Identity Federation requires configuration on both Azure and GCP.

## Overview
<img src="azure-gcp-wif.svg" >

## GCP Configuration

To configure GCP to run the gcloud scripts see [GCloud FAQ](https://github.com/DFE-Digital/teacher-services-analytics-cloud/blob/main/documentation/gcloud-faq.md).

## GCloud scripts and documentation

For GCloud WIF helper scripts and documentation see [GCloud scripts](https://github.com/DFE-Digital/teacher-services-analytics-cloud/tree/main/scripts/gcloud) and [Documentation](https://github.com/DFE-Digital/teacher-services-analytics-cloud/blob/main/documentation/gcloud-scripts.md).

## Azure configuration
[The required resources](https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster) are added per namespace. Add namespaces to the `gcp_wif_namespaces` variable list to enable WIF. This creates a service account in the namespace, linked to a managed identity with specific federated credentials.

## Applications
To enable the feature for an application in the namespace:
- Set `enable_gcp_wif = true`
- Download the Google credentials from the connected service account
- Set the GOOGLE_CLOUD_CREDENTIALS environment variable via from key vault
- For the dfe-analytics ruby gem, set `config.azure_federated_auth = true`
