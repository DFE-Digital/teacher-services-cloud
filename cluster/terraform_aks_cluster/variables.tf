# Set in config shell variables and used by Makefile
variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "resource_prefix" { type = string }
variable "azure_tags" { type = string }
variable "config" { type = string }
variable "managed_identity_name" {
  type        = string
  description = "Name of the managed identiy assumed by the cluster for its control plane"
}

# Set in config json file
variable "cip_tenant" { type = bool }
variable "default_node_pool" { type = map(any) }
variable "node_pools" { type = any }
variable "kubernetes_version" { type = string }
variable "clone_cluster" {
  type    = bool
  default = false
}

locals {
  backing_services_resource_group_name = "${var.resource_prefix}-tsc-${var.environment}-bs-rg"
  cluster_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-${var.environment}-aks" :
    "${var.resource_prefix}aks-tsc-${var.environment}"
  )
  clone_cluster_name = "${var.resource_prefix}-tsc-${var.environment}-clone-aks"
  node_resource_group_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-rg" :
    "${var.resource_prefix}rg-tsc-aks-nodes-${var.environment}"
  )
  clone_node_resource_group_name = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-clone-rg"
  dns_prefix                     = "${var.resource_prefix}-tsc-${var.environment}"
  vnet_name                      = "${var.resource_prefix}-tsc-${var.environment}-vnet"
  subnets = {
    postgres-snet = {
      cidr_range = "10.2.0.0/18",
      delegation = {
        name = "postgres-delegation"
        service-delegation = {
          name = "Microsoft.DBforPostgreSQL/flexibleServers",
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/join/action"
          ]
        }
      }
    },
    redis-snet = {
      cidr_range = "10.2.64.0/18",
      delegation = {}
    }
  }
  custom_dns_zone_name_suffixes = [
    "internal.postgres.database.azure.com"
  ]
  privatelink_dns_zone_names = [
    "privatelink.redis.cache.windows.net"
  ]
  uk_south_availability_zones = ["1", "2", "3"]
}
