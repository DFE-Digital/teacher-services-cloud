# Service Requests Dashboard

## Overview

The Service Requests Dashboard provides a comprehensive view of HTTP request metrics for all services running in the AKS cluster. It replaces the previous PaaS dashboard functionality by showing request counts grouped by HTTP status codes (2xx, 4xx, 5xx).

## Features

- **Aggregate View**: Overall request metrics across all services grouped by status code
- **Per-Service Panels**: Individual graphs for each service showing request breakdown
- **Status Code Grouping**: Color-coded visualization:
  - 🟢 Green: 2xx (Success)
  - 🟡 Yellow: 4xx (Client Errors)
  - 🔴 Red: 5xx (Server Errors)
- **Time Range**: Default last 1 hour, easily adjustable
- **Auto-refresh**: 30-second refresh interval
- **Filtering**: Filter by service/ingress and namespace

## Dashboard Location

- **File**: `cluster/terraform_kubernetes/config/dashboards/service-requests-dashboard.json`
- **Grafana URL**: `https://grafana.{cluster-domain}/`
- **Dashboard Title**: "Service Requests Dashboard"

## Dashboard Components

### 1. All Services Overview Panel
Shows aggregate request rate across all services with HTTP status code breakdown. Useful for:
- Identifying overall system health
- Detecting widespread issues
- Monitoring total traffic patterns

### 2. Per-Service Panels
Dynamically generated panels, one per service/ingress, showing:
- Request rate (requests per second)
- HTTP status code distribution
- Individual service health trends

## Variables/Filters

### Service Filter
- **Variable**: `$service`
- **Type**: Multi-select dropdown
- **Source**: Auto-populated from `nginx_ingress_controller_requests` metric labels
- **Default**: All services
- **Usage**: Select specific services to focus the dashboard view

### Namespace Filter
- **Variable**: `$namespace`
- **Type**: Multi-select dropdown
- **Source**: Auto-populated from `nginx_ingress_controller_requests` metric labels
- **Default**: All namespaces
- **Usage**: Filter by Kubernetes namespace (e.g., BAT, CPD, GIT services)

## Prometheus Queries

### All Services Overview
```promql
sum(rate(nginx_ingress_controller_requests{namespace!=""}[$__rate_interval])) by (status)
```

### Per-Service Metrics
```promql
sum(rate(nginx_ingress_controller_requests{ingress="$service"}[$__rate_interval])) by (status)
```

## Use Cases

### Monitoring Service Health
- Quick identification of services with high error rates (4xx/5xx)
- Trend analysis for request patterns
- Capacity planning based on request volumes

### Incident Response
- Rapid identification of affected services
- Correlation of errors across multiple services
- Historical comparison during incidents

### Service Line Analysis
If the dashboard becomes resource-intensive, you can:
1. Use the namespace filter to focus on specific service lines (BAT, CPD, GIT)
2. Create separate dashboards per service line by duplicating and modifying the dashboard
3. Adjust the time range to reduce query load

## Deployment

The dashboard is automatically deployed via Terraform:

1. **Automatic Provisioning**: The dashboard JSON file in `config/dashboards/` is automatically picked up by the Terraform configuration
2. **ConfigMap**: Loaded into the `grafana-dashboards` ConfigMap in the `monitoring` namespace
3. **Grafana**: Auto-provisioned when Grafana pod starts

### Manual Deployment Steps

If you need to manually update the dashboard:

```bash
# 1. Edit the dashboard JSON file
vim cluster/terraform_kubernetes/config/dashboards/service-requests-dashboard.json

# 2. Apply Terraform changes
make <environment> terraform-plan
make <environment> terraform-apply

# 3. Restart Grafana pod (optional, for immediate reload)
kubectl rollout restart deployment/grafana -n monitoring
```

## Performance Considerations

### Resource Usage
- **Light Load**: Single panel showing all services aggregated
- **Moderate Load**: ~10-20 service panels
- **Heavy Load**: >20 service panels may impact Grafana performance

### Optimization Strategies

If performance becomes an issue:

1. **Increase Refresh Interval**: Change from 30s to 1m or higher
2. **Reduce Time Range**: Use shorter default time ranges (30m instead of 1h)
3. **Split by Service Line**: Create separate dashboards:
   - `service-requests-bat.json` (BAT services only)
   - `service-requests-cpd.json` (CPD services only)
   - `service-requests-git.json` (GIT services only)

To create service-line specific dashboards:
```bash
# Copy the base dashboard
cp service-requests-dashboard.json service-requests-bat.json

# Edit the JSON and add namespace filter to queries:
# Change: nginx_ingress_controller_requests{ingress="$service"}
# To: nginx_ingress_controller_requests{ingress="$service", namespace=~".*bat.*"}
```

## Troubleshooting

### No Data Displayed
- Verify Prometheus is scraping nginx-ingress-controller metrics
- Check that services have active traffic
- Confirm nginx-ingress-controller is deployed and running

### Missing Services
- Services appear in the dropdown only if they have received requests
- Check the nginx-ingress-controller is properly configured for the service
- Verify the service has an Ingress resource defined

### Performance Issues
- Reduce the number of selected services
- Increase refresh interval
- Shorten time range
- Consider splitting into service-line specific dashboards

## Related Documentation

- [Monitoring](monitoring.md) - Overall monitoring strategy
- [Nginx Ingress Controller Dashboard](../cluster/terraform_kubernetes/config/dashboards/nginx-ingress-controller.json) - Original ingress-level dashboard
- [Grafana Configuration](../cluster/terraform_kubernetes/grafana.tf) - Terraform configuration

## Metrics Reference

The dashboard uses the `nginx_ingress_controller_requests` metric which provides:

- **Labels**:
  - `ingress`: Name of the ingress/service
  - `namespace`: Kubernetes namespace
  - `status`: HTTP status code (200, 404, 500, etc.)
  - `method`: HTTP method (GET, POST, etc.)
  - `host`: Request host header

- **Metric Type**: Counter
- **Collection**: Prometheus via nginx-ingress-controller exporter
- **Retention**: Subject to Thanos retention policy (see [Monitoring](monitoring.md))

## Future Enhancements

Potential improvements to consider:

1. **Service Line Organization**: Add service line labels/tags for better filtering
2. **SLO Integration**: Add SLO violation indicators
3. **Alert Integration**: Link to related alerts for each service
4. **Latency Metrics**: Add P95/P99 latency alongside request counts
5. **Rate Change Detection**: Highlight sudden changes in request patterns
