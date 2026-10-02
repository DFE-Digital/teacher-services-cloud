# Airbyte base resources deployment

We want to use [Airbyte](https://airbyte.com) to send selected database information from Azure Postgres to BigQuery.
This is a separate terraform configuration for deploying the base airbyte services within an AKS cluster.
Airbyte Connections (source and destination for each environment) can then be configured within each service using our terraform airbyte module where appropriate.

We install a single airbyte deployment per namespace, and this will be shared by all services and environments in that namespace.
A default workspace is created initially, but this is not used by services. Instead, we create a separate workspace for each service to maintain separation. A service will only access it's own workspace.

Most of the airbyte resources are deployed using the Airbyte helm chart.
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

### Required Steps

1. Create the secret AIRBYTE-PASS-${namespace} in the cluster keyvault (s189t01-tsc-ts-kv & s189p01-tsc-pd-kv). To follow the same standard, use at least 16 characters, all lowercase, three words with no separation.
2. Add the namespace to the airbyte_namespaces variable in the appropriate cluster json tfvars file e.g. airbyte/terraform/config/test.tfvars.json or airbyte/terraform/config/production.tfvars.json.
3. run make as below
```
make test airbyte-apply CONFIRM_TEST=yes
```
```
make production airbyte-apply CONFIRM_PRODUCTION=yes
```
4. Note that the airbyte ui account will be set to the account you use on first login. So, immediately after initial build, log in to the Airbyte URL as defined in our Airbyte Loop document using the password secret you created in step 1.
   1. The email is always the same. See our Loop Airbyte page for this vale.
   2. The Organization name should be `Schools Digital UK`
   3. Enable `Anonymize usage data collection`
   4. If the receive `Invalid username or password`, taint the helm chart and redeploy.
      1. Add `-replace='helm_release.airbyte[${namespace}]' to the airbyte-apply command in the make file so it looks something like this
      ```
      airbyte-apply: airbyte-init
	  terraform -chdir=airbyte/terraform apply -replace='helm_release.airbyte["git-test"]' -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}

      or for multiple
      airbyte-apply: airbyte-init
      terraform -chdir=airbyte/terraform apply -replace='helm_release.airbyte["git-production"]' -replace='helm_release.airbyte["srtl-production"]' -replace='helm_release.airbyte["tv-production"]' -var-file config/${CONFIG}.tfvars.json ${AUTO_APPROVE}

      ```

    To change it after initial login requires a complete rebuild, so make sure you use the correct initial email.

5. A single airbyte API application will be created. The client_id and client_secret are randomly created and kept in the kubernetes secret airbyte-auth-secrets. Either check the ui or decode with base64 for the true values which can then be used by the services to connect to the airbyte api.
   1. Go to the Airbyte UI -> Settings -> Applications

A single workspace is created initially. To separate services and environments within the same namespace, separate connections are created within the single Airbyte workspace.
