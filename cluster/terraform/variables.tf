# Set in config shell variables and used by Makefile
variable "azure_sp_credentials_json" {
  default = null
  type    = string
}
variable "azure_tags" { type = string }
variable "environment" {}
variable "resource_prefix" {}
variable "resource_group_name" {}
variable "cluster_dns_resource_group_name" { default = null }
variable "cluster_dns_zone" {
  description = "The name of the DNS zone containing A records pointing to the ingress public IPs.  This is only used for the development environment"
  default     = null
  type        = string
}
variable "cluster_kv" {}
variable "config" {}
variable "ingress_cert_name" {
  type    = string
  default = null
}

# Set in config json file
variable "cip_tenant" { type = bool }
variable "namespaces" {}

locals {
  azure_credentials                    = try(jsondecode(var.azure_sp_credentials_json), null)
  backing_services_resource_group_name = "${var.resource_prefix}-tsc-${var.environment}-bs-rg"
  cluster_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-${var.environment}-aks" :
    "${var.resource_prefix}aks-tsc-${var.environment}"
  )
  node_resource_group_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-rg" :
    "${var.resource_prefix}rg-tsc-aks-nodes-${var.environment}"
  )
  dns_prefix = "${var.resource_prefix}-tsc-${var.environment}"
  default_ingress_cert_name = (var.environment == var.config ?
    "${var.environment}-teacherservices-cloud" :             # For non dev environments, config is the same as environment
    "${var.environment}-${var.config}-teacherservices-cloud" # Development environments have unique names but share the same config
  )
  cluster_cert_secret = (var.ingress_cert_name != null ?
    var.ingress_cert_name : # Override certificate name if required for this environment
    local.default_ingress_cert_name
  )
  vnet_name = "${var.resource_prefix}-tsc-${var.environment}-vnet"
  subnets = {
    postgres-snet = {
      cidr_range = "10.2.0.0/18",
      delegations = {
        postgres-delegation = {
          name = "Microsoft.DBforPostgreSQL/flexibleServers",
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/join/action"
          ]
        }
      }
    }
  }
  node_pools = {
    applications = {
      vm_size    = "Standard_D2_v2",
      node_count = "1"
    }
  }
}
