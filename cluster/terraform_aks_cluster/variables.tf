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
variable "ci_collection_interval" {
  type        = string
  default     = "5m"
  description = "Container Insights data collection interval"
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
variable "admin_group_id" {
  type        = string
  description = "Object Id of the cluster admins Entra ID group"
}
variable "enable_azure_RBAC" {
  type        = bool
  default     = true
  description = "Enable Azure AD RBAC on this cluster"
}
variable "enable_azure_RBAC_clone" {
  type        = bool
  default     = true
  description = "Enable Azure AD RBAC on the clone cluster"
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
  monitor_action_group_name   = "${var.resource_prefix}-tsc"
  monitoring_resource_group   = "${var.resource_prefix}-tsc-mn-rg"
  required_available_nodes    = 2
  node_threshold              = var.node_pools["apps1"].max_count + var.default_node_pool.node_count - local.required_available_nodes
}
