variable "environment" {}
variable "resource_group_name" {}
variable "resource_prefix" {}
variable "config" {}
variable "azure_tags" { type = string }

variable "cip_tenant" { type = bool }
variable "default_node_pool" { type = map(any) }
variable "node_pools" { type = map(any) }

locals {
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
  vnet_name  = "${var.resource_prefix}-tsc-${var.environment}-vnet"
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
