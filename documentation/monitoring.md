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

## AKS Cluster Authentication

An AKS cluster authentication smoke test runs on a [GitHub Workflow](https://github.com/DFE-Digital/teacher-services-cloud/blob/main/.github/workflows/cluster_access_test.yml) initiated via crontab schedule every 5 mins, accessing all clusters.
It authenticates to Azure via OIDC and runs a simple k8s command to verify all is well.
If the script fails it triggers a Slack webhook to the [#infra-alert-public channel](https://app.slack.com/client/T50RK42V7/C08ND0YCYCA).

## Prometheus

Prometheus monitoring is enabled for a cluster by default.

The default prometheus version is hardcoded in the kubernetes variables.tf. It can be overridden for a cluster by adding prometheus_version to the env.tfvars.json file.

There are several other variables that can be changed depending on env requirements.
- prometheus_app_mem - app memory limit (default 1G)
- prometheus_app_cpu - app memory requests (default 100m)
- prometheus_tsdb_retention_time - local storage retention period (default 6h)

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

The default thanos version is hardcoded in the kubernetes variables.tf. It can be overridden for a cluster by adding thanos_version to the env.tfvars.json file.

There are several other variables that can be changed depending on env requirements.
- thanos_app_mem - sidecar memory limit (default 1G)
- thanos_app_cpu - thanos cpu requests (default 100m)
- thanos_querier_mem - app memory limit for the thanos querier (default 1G)
- thanos_compactor_mem - app memory limit for the thanos compactor (default 1G)
- thanos_store_mem - app memory limit for the thanos store gateway (default 1G)
- thanos_retention_raw - Thanos retention period for raw samples (default 30d)
- thanos_retention_5m - Thanos retention period for 5m samples (default 60d)
- thanos_retention_1h - Thanos retention period for 1h samples (default 90d)

### Metrics Retention

Metrics retention is based on sampling
- Raw data(actual data captured) is retained for 30 days. This is data as it is captured by prometheus.
- 5m down samples are retained for 60days.This is data point for a metric 5m apart.
- 1hr down samples are retained for 90 days. This is data point for a metric 1hr apart.

More information on down sampling is available on this [link](https://thanos.io/v0.8/components/compact/#downsampling-resolution-and-retention)

Down sample allows for reduced storage costs as all the raw data does not need to stored for longer duration charting.

### Thanos UI
Metrics can be queried/charted by using thanos UI. While charting metrics in thanos the following should be noted

- Change the data source to **prometheus** or **thanos**. See this [image](thanos-dropdown.png)


### Raw Data Sampling
- Thanos UI allows for querying raw data. However, it retains raw data for only 30 days. Raw data can be queries created by selecting `Only raw data` as below. If more than 30 days is queried for raw data, the charts based on raw data will not show data more than 30 days. See [image](thanos-raw-sample.png)

### 5m down sample
Beyond 30days - thanos down samples the data. `5m down sample` stores samples for 60 days.  See [image](thanos-5m-down-sample.png)

### 1hr down sample
`1hr down sample` stores metric samples for 90 days. See [image](thanos-1h-down-sample.png)

### Auto down sample
This option is used by grafana when during charting/visualisation. Where the charts are over a long period of time grafana adopts the most appropriate down sampling for data.

## Grafana

Grafana provides a visual interface for monitoring logs and metric.
It can be configured to different datasources including prometheus and thanos (as it is, in this case).
Grafana dashboard can be configured as required to provide different forms of visualisation - inluding charts, graphs etc

The default grafana version is hardcoded in the kubernetes variable.tf. It can be overridden for a cluster by adding grafana_version to the env.tfvars.json file.

There are several other variables that can be changed depending on env requirements.
- grafana_app_mem - app memory limit (default 1Gi)
- grafana_app_cpu - app requests cpu (default 500m)

## kube state metrics

Kube-state-metrics is a listening service that generates metrics about the state of Kubernetes objects through leveraging the Kubernetes API; it focuses on object health instead of component health

The default Kube-state-metrics version is hardcoded to version v2.8.2 by adding kube_state_metrics_version to variables.tf

The metrics scraped are:
- requests -  with  cpu   of  100m and memory of 128Mi
- limits - with cpu  of  300m and memory of 256Mi
- liveness_probe - with endpoint /healthz and port 8080
- readiness_probe - with endpoint / and port 8081
- telemetry - the telemetry data is accesses via port 8081

## Alertmanager

Alertmanager handles alerts sent by client applications such as the Prometheus server. It takes care of deduplicating, grouping, and routing them to the correct receiver integration such as email, Slack, or other notification mechanisms.

Alertmanager service is running on NodePort 9093.

Alertmanager is a single replica deployment.

The default alert version is hardcoded in the kubernetes variable.tf. It can be overridden for a cluster by adding alertmanager_image_version to the env.tfvars.json file.

There are several other variables that can be changed depending on env requirements.
- alertmanager_app_mem - app memory limit (default 1G)
- alertmanager_app_cpu - app cpu requests (default 1)

## Node Exporter

The node exporter enables o/s and hardware metrics for each node.

It's deployed as a daemon set, which creates a node-exporter pod in each node on the cluster.
Prometheus then scrapes port 9100 on each of these pods.

The default node exporter version is hardcoded in the kubernetes variables.tf. It can be overridden for a cluster by adding node_exporter_version to the env.tfvars.json file.

### PROMETHEUS , ALERTMANAGER and THANOS Auth Key generation.

For auth key generation run the shell script 'scripts/hash_password.sh' by passing username and password , then take the generated key save in to azure vault as a secret. User and password will be stored as clear text in PROMETHEUS-AUTH-CLEAR,ALERTMANAGER-AUTH-CLEAR,THANOS-AUTH-CLEAR

Following auth keys need to be stored on azure vault as a secret.
1. PROMETHEUS-AUTH
2. ALERTMANAGER-AUTH
3. THANOS-AUTH

### Azure Monitor Alerting

Azure Monitor is used to track the health and performance of the AKS clusters. The monitoring is configured through Terraform in the `azure_metric_alerts.tf` file.

#### Node Availability Monitoring

A metric alert is configured to monitor the availability of nodes in the AKS cluster:

- Alert Name: `[resource-prefix]-tsc-[environment]-nodes-capacity`
- Metric: `kube_node_status_condition`
- Evaluation: Every 1 minute over a 5-minute window
- Threshold: Triggers when the number of available nodes with "Ready" status exceeds the configured threshold
- Action: Notifications are sent to the configured Azure Monitor Action Group

The alert helps ensure the cluster maintains sufficient node capacity for workloads. The action group is configured to notify the appropriate team members when node availability issues are detected.

Configuration is managed through Terraform variables:
- The monitoring resource group and action group are defined in the cluster configuration
- The action group name follows the format `[resource-prefix]-tsc`
- Alert thresholds can be customized per environment
- The metric namespace used is `microsoft.containerservice/managedclusters`

### High Port Usage

AKS uses an azure load balancer for inbound and outbound connections and this can lead to port exhaustion if a node does alot of network requests.

If port usage goes over a threshold we alert on this as a warning so we can take pre-emptive action.

### Port Exhaustion

If connections start failing because of port exhaustion we alert on this as an error.

### Troubleshooting Port Exhaustion

Unfortunately we can't alert which kubernetes service is using aa high number of ports so this is a troublshooting exercise following:

[Troubleshoot SNAT port exhaustion on Azure Kubernetes Service nodes](https://learn.microsoft.com/en-us/troubleshoot/azure/azure-kubernetes/connectivity/snat-port-exhaustion?tabs=for-a-linux-pod)