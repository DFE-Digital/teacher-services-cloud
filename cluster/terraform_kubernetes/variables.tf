# Set via TF_VAR environment variable in the workflow
variable "azure_sp_credentials_json" {
  default = null
  type    = string
}

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

  azure_credentials = try(jsondecode(var.azure_sp_credentials_json), null)
}
