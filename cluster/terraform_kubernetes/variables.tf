# Set in config shell variables and used by Makefile
variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "resource_prefix" { type = string }
variable "config" { type = string }

# Set in config json file
variable "cluster_dns_resource_group_name" {
  type    = string
  default = null
}
variable "cluster_dns_zone" {
  description = "The name of the DNS zone containing A records pointing to the ingress public IPs.  This is only used for the development environment"
  default     = null
  type        = string
}

variable "cluster_kv" { type = string }

variable "cip_tenant" { type = bool }

variable "ingress_cert_name" {
  type    = string
  default = null
}
variable "namespaces" { type = list(string) }
variable "gcp_wif_namespaces" {
  description = "List of namespaces with Azure GCP Wokload Identity Federation enabled"
  type        = list(string)
  default     = []
}

variable "statuscake_alerts" {
  type    = map(any)
  default = {}
}

variable "clone_cluster" {
  type    = bool
  default = false
}

variable "welcome_app_hostnames" {
  description = "Full hostname to enable the welcome app on this domain"
  type        = list(any)
  default     = []
}

variable "ingress_nginx_version" {
  description = "Version of the ingress-nginx helm chart to use"
  type        = string
  default     = "4.11.0"
}

variable "enable_lowpriority_app" {
  type    = bool
  default = false
}

variable "grafana_app_cpu" {
  type    = string
  default = "500m"
}

variable "grafana_app_mem" {
  type    = string
  default = "500M"
}

variable "grafana_limit_mem" {
  type    = string
  default = "1Gi"
}

variable "grafana_version" {
  type    = string
  default = "11.1.5"
}

variable "lowpriority_app_cpu" {
  type    = string
  default = "1"
}

variable "lowpriority_app_mem" {
  type    = string
  default = "1500Mi"
}

variable "lowpriority_app_replicas" {
  type    = number
  default = 3
}

variable "kube_state_metrics_version" {
  type    = string
  default = "2.13.0"
}

data "azurerm_client_config" "current" {}

data "environment_variables" "github_actions" {
  filter = "GITHUB_ACTIONS"
}

variable "prometheus_version" {
  type    = string
  default = "v2.54.1"
}

variable "prometheus_tsdb_retention_time" {
  type        = string
  description = "Prometheus retention period for locally stored data"
  default     = "6h"
}

variable "prometheus_app_mem" {
  type        = string
  description = "Prometheus app memory limit"
  default     = "1Gi"
}

variable "prometheus_app_cpu" {
  type        = string
  description = "Prometheus app cpu request"
  default     = "100m"
}

variable "thanos_version" {
  type    = string
  default = "v0.36.1"
}

variable "thanos_app_mem" {
  type        = string
  description = "Thanos sidecar memory limit"
  default     = "1Gi"
}

variable "thanos_querier_mem" {
  type        = string
  description = "Thanos querier memory limit"
  default     = "1Gi"
}

variable "thanos_compactor_mem" {
  type        = string
  description = "Thanos compactor memory limit"
  default     = "1Gi"
}

variable "thanos_store_mem" {
  type        = string
  description = "Thanos store gateway memory limit"
  default     = "1Gi"
}

variable "thanos_app_cpu" {
  type        = string
  description = "Thanos app cpu request"
  default     = "100m"
}

variable "thanos_retention_raw" {
  type        = string
  description = "Thanos retention period for raw samples"
  default     = "30d"
}

variable "thanos_retention_5m" {
  type        = string
  description = "Thanos retention period for 5m samples"
  default     = "60d"
}

variable "thanos_retention_1h" {
  type        = string
  description = "Thanos retention period for 1h samples"
  default     = "90d"
}

variable "cluster_short" {
  type        = string
  description = "Short name of the cluster configuration, e.g. dv, pt, ts, pd"
}

variable "alertmanager_image_version" {
  type    = string
  default = "v0.27.0"
}

variable "alertmanager_app_cpu" {
  type    = string
  default = "100m"
}

variable "alertmanager_app_mem" {
  type    = string
  default = "1Gi"
}
variable "node_exporter_version" {
  type    = string
  default = "v1.8.2"
}
variable "filebeat_version" {
  type    = string
  default = "8.12.2"
}

variable "alertmanager_slack_receiver_list" {
  type        = list(any)
  description = "List of alertmanager Slack receivers. Each entry must have a corresponding webhook in the keyvault."
  default     = []
}

variable "alertable_apps" {
  type        = map(any)
  description = "Map of deployments which we want to monitor. Each key contains a map to override the default values."
  default     = {}
}

variable "block_metrics_endpoint" {
  description = "Block metric endpoints"
  default     = true
  type        = bool
}

variable "ga_wif_managed_id" {
  default = {}
  type    = map(map(list(string)))
}

locals {
  cluster_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-${var.environment}-aks" :
    "${var.resource_prefix}aks-tsc-${var.environment}"
  )
  clone_cluster_name = "${var.resource_prefix}-tsc-${var.environment}-clone-aks"
  default_ingress_cert_name = (var.environment == var.config ?
    "${var.environment}-teacherservices-cloud" :             # For non dev environments, config is the same as environment
    "${var.environment}-${var.config}-teacherservices-cloud" # Development environments have unique names but share the same config
  )
  cluster_cert_secret = (var.ingress_cert_name != null ?
    var.ingress_cert_name : # Override certificate name if required for this environment
    local.default_ingress_cert_name
  )
  api_token = data.azurerm_key_vault_secret.statuscake_secret.value

  welcome_app_name          = "welcome-app"
  welcome_app_namespace     = "infra"
  lowpriority_app_name      = "lowpriority-app"
  lowpriority_app_namespace = "infra"

  rbac_enabled = length(data.azurerm_kubernetes_cluster.main.azure_active_directory_role_based_access_control) > 0
  rbac_enabled_clone = try(
    length(data.azurerm_kubernetes_cluster.clone[0].azure_active_directory_role_based_access_control) > 0,
    false
  )

  kubelogin_spn_args = [
    "get-token",
    "--login",
    "spn",
    "--environment",
    "AzurePublicCloud",
    "--tenant-id",
    data.azurerm_client_config.current.tenant_id,
    "--server-id",
    "6dae42f8-4368-4678-94ff-3960e28e3630" # See https://azure.github.io/kubelogin/concepts/aks.html
  ]
  kubelogin_azurecli_args = [
    "get-token",
    "--login",
    "azurecli",
    "--server-id",
    "6dae42f8-4368-4678-94ff-3960e28e3630"
  ]

  spn_authentication = contains(keys(data.environment_variables.github_actions.items), "GITHUB_ACTIONS")
  kubelogin_args     = local.spn_authentication ? local.kubelogin_spn_args : local.kubelogin_azurecli_args

  template_variable_map = {
    storage-account-name = azurerm_storage_account.thanos.name
    storage-account-key  = azurerm_storage_account.thanos.primary_access_key
  }

  filebeats_template_variable_map = {
    BEATS_URL = data.azurerm_key_vault_secret.beats_url.value
  }

  cluster_sa_name = (var.environment == var.config ?
    var.cluster_short : # pt,ts or pd
    var.environment     # cluster1, cluster2, etc
  )

  # Alert manager
  alertmanager_slack_receiver_map = {
    for r in var.alertmanager_slack_receiver_list : r => data.azurerm_key_vault_secret.slack_webhooks[replace(r, "_", "-")].value
  }

  slack_secret_names = [for s in data.azurerm_key_vault_secrets.main.names : s if startswith(s, "SLACK-WEBHOOK")]

  app_alert_rules_variables = {
    apps = [for instance, settings in var.alertable_apps : {
      namespace       = split("/", instance)[0]
      app_name        = split("/", instance)[1]
      max_cpu         = try(settings.max_cpu, 0.8)
      max_mem         = try(settings.max_mem, 0.8)
      max_crash_count = try(settings.max_crash_count, 1)
      receiver        = try(settings.receiver, "SLACK_WEBHOOK_GENERIC")
      }
    ]
  }

  app_alert_rules = length(var.alertable_apps) == 0 ? "" : templatefile("${path.module}/config/prometheus/alertmanager/app_alert.rules.tmpl", local.app_alert_rules_variables)

  node_alert_rules_variables = {
    cluster_long = local.cluster_name
  }

  node_alert_rules = templatefile("${path.module}/config/prometheus/alertmanager/node_alert.rules.tmpl", local.node_alert_rules_variables)

  alertmanager_config_content = templatefile(
    "${path.module}/config/prometheus/alertmanager/alertmanager.yml.tmpl", {
      slack_url       = data.azurerm_key_vault_secret.slack_webhooks["SLACK-WEBHOOK-GENERIC"].value
      slack_receivers = local.alertmanager_slack_receiver_map
    }
  )

  template_files = {
    "slack.tmpl" = "${path.module}/config/prometheus/alertmanager/alertmanager-slack.yaml"
  }

  alertmanager_templates = { for k, v in local.template_files : k => file(v) }

  # Get value from helm_release attribute to force dependency
  # and make sure the ingress controller is created before the ingresses
  ingress_class_name = jsondecode(helm_release.ingress-nginx.metadata[0].values)["controller"]["ingressClassResource"]["name"]

  default_welcome_app_hostname = "www.${module.cluster_data.ingress_domain}"
  welcome_app_hostnames        = concat(var.welcome_app_hostnames, [local.default_welcome_app_hostname])
}
