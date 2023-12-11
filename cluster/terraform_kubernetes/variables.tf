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
  default     = "4.4.0"
}

variable "enable_lowpriority_app" {
  type    = bool
  default = false
}

variable "lowpriority_app_cpu" {
  default = "1"
}

variable "lowpriority_app_mem" {
  default = "1500Mi"
}

variable "lowpriority_app_replicas" {
  default = 3
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
}
