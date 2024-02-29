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
prometheus_app_cpu - app memory requests (default 100m)
prometheus_tsdb_retention_time - local storage retention period (default 6h)

Prometheus rules and yml config files are loaded from the terraform_kubernetes/config/prometheus directory. Each file is prefixed with the cluster env.
e.g. development.prometheus.rules and development.prometheus.yml
Currently a restart/reload of the prometheus process is required if changes are made to these files.

## Thanos

Prometheus is configured to use Thanos for backend storage.

Thanos runs as a sidecar within the prometheus deployment.
It copies prometheus collected data after two hours to an Azure storage container.

There are also three separate Thanos services
- thanos-querier
- thanos-store-gateway
- thanos-compactor
All are running as single replica deployments.

The default thanos version is hardcoded in the kubernetes variable.tf. It can be overridden for a cluster by adding thanos_version to the env.tfvars.json file.
There are several other variables that can be changed depending on env requirements.
thanos_app_mem - app memory limit (default 1G)
thanos_app_cpu - app memory requests (default 100m)
thanos_retention_raw - Thanos retention period for raw samples (default 30d)
thanos_retention_5m - Thanos retention period for 5m samples (default 60d)
thanos_retention_1h - Thanos retention period for 1h samples (default 90d)


## Grafana

Grafana provides a visual interface for monitoring logs and metric.
It can be configured to different datasources including prometheus and thanos (as it is, in this case).
Grafana dashboard can be configured as required to provide different forms of visualisation - inluding charts, graphs etc

The default grafana version is hardcoded in the kubernetes variable.tf. It can be overridden for a cluster by adding grafana_version to the env.tfvars.json file.
There are several other variables that can be changed depending on env requirements. e.g.
grafana_app_mem - app memory limit (default 1Gi)
grafana_app_cpu - app requests cpu (default 500m)

## kube state metrics
Kube-state-metrics is a listening service that generates metrics about the state of Kubernetes objects through leveraging the Kubernetes API; it focuses on object health instead of component health

The default Kube-state-metrics version is hardcoded to version v2.8.2 by adding kube_state_metrics_version to variables.tf
The metrics scraped are:
requests -  with  cpu   of  100m and memory of 128Mi
limits - with cpu  of  300m and memory of 256Mi
liveness_probe - with endpoint /healthz and port 8080
readiness_probe - with endpoint / and port 8081
telemetry - the telemetry data is accesses via port 8081
