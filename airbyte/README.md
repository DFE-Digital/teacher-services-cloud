# Airbyte base resources deployment

We want to use [Airbyte](https://airbyte.com) to send selected database information from Azure Postgres to BigQuery.
This is a separate terraform configuration for deploying the base airbyte services within an AKS cluster.
Airbyte Connections (source and destination for each environment) can then be configured within each service using our terraform airbyte module where appropriate.

We install a single airbyte deployment per namespace, and this will be shared by all services and environments in that namespace.
A default workspace is created initially, but this is not used by services. Instead, we create a separate workspace for each service to maintain separation. A service will only access it's own workspace.

Most of the airbyte resources are deployed using the airbye helm chart.
We use an Azure storage account for logs, and an Azure postgresql server for airbyte data.
A lifecycle policy deletes log data after 14 days, and for the database TEMPORAL_HISTORY_RETENTION_IN_DAYS is set to 7 days.

## Directory Layout

```
- terraform
    *.tf files for high-level configuration using the airbyte and helm providers
    - config
            *.tfvars.json config files for each cluster environment

- scripts
    bash scripts for common functions

Dockerfile
    used to build a curl image
```

## Operation

### Prerequisites

- Create secrets for AIRBYTE-PASS-${namespace} in the cluster keyvault
- Add namespace to the airbyte_namespaces variable in the appropriate cluster json tfvars file e.g. airbyte/terraform/config/test.tfvars.json
- run make as below
- Note that the airbyte ui account will be set to the account you use on first login. So, immediately after initial build you should log in using the password secret and the infra email. To change it after initial login requires a complete rebuild, so make sure you use the correct initial email.
- a single airbyte API application will be created. The client_id and client_secret are randomly created and kept in the kubernetes secret airbyte-auth-secrets. Either check the ui or decode with base64 for the true values which can then be used by the services to connect to the airbyte api (stored as key vault secrets)
- a single workspace is created initially. To separate services and environments within the same namespace, we wouldn't give the default workspace to services. Instead create extra workspaces as required. Two scripts have been created to do this, list-workspaces.sh and create-workspaces.sh. You must export some local variables before running, see the scripts for details.

### Airbyte Build

#### Development environments: cluster1, cluster2...

```
make development airbyte-{plan/apply} ENVIRONMENT=cluster{n}
```

where n = 1-6

e.g.
```
make development airbyte-plan ENVIRONMENT=cluster1
```

#### Permanent environments: platform-test, test, production

```
make <environment> airbyte-{plan/apply} CONFIRM...
```

e.g.
```
make test airbyte-plan CONFIRM_TEST=yes
```
