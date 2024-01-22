# Monitoring

Details for any cluster or subscription monitoring

## Subscription monitoring

Manually created service health alerts for each s189 subscription.

s189[d|t|p]-service-health-alert

They will trigger on the below events for UK South or Global regions, and send an email to the TS infra team
- service issue
- planned maintenance
- health advisories
- security advisory

## Cluster statuscake alerts

Terraform created statuscake monitoring for the permanent clusters.

These monitor https://status.${cluster}/healthz for each cluster,
and will email and page the TS infra team on failure.

## Prometheus

Prometheus monitoring is enabled for a cluster by default.

The default prometheus version is hardcoded in the kubernetes variable.tf. It can be overridden for a cluster by adding prometheus_version to the env.tfvars.json file.
There are several other variables that can be changed depending on env requirements.
prometheus_app_mem - app memory limit (default 1G)
prometheus_tsdb_retention_time - local storage retention period

Prometheus rules and yml config files are loaded from the terraform_kubernetes/config/prometheus directory. Each file is prefixed with the cluster env.
e.g. development.prometheus.rules and development.prometheus.yml
Currently a restart/reload of the prometheus process is required if changes are made to these files.
