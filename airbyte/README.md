# Airbyte deployment

Separate terraform configuration for deployment the base airbyte services.

We deploy a single airbyte deployment per namespace, and this will be shared by all services and environments in that namespace.


## Directory Layout

```
- terraform
    *.tf files for high-level configuration using the airbyte and helm providers
    - config
            *.tfvars.json config files for each cluster environment

Makefile
```

## Operation

### Prerequisites

- Create secrets for AIRBYTE-PASS-${namespace} in the cluster keyvault
- Add namespace to the airbyte_namespaces variable in the appropriate cluster json tfvars file e.g. airbyte/terraform/config/test.tfvars.json
- run make as below
- Note that the airbyte ui account will be set to the account you use on first login. So, immediately after initial build you should log in using the password secret and the infra email. To change it after initial login appears to require contacting airbyte support, so make sure you use the correct initial email.
- a single airbyte API application will be created. The client_id and client_secret are randomly created and kept in the kubernetes secret airbyte-auth-secrets. Decode with base64 for the true values, which can then be used by the services to connect to the airbyte api (stored as key vault secrets)

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

### Internal
