# Set via TF_VAR environment variable in the workflow
variable "azure_sp_credentials_json" {
  default = null
  type    = string
}

# Set in config shell variables and used by Makefile
variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "resource_prefix" { type = string }
variable "azure_tags" { type = string }
variable "config" { type = string }

# Set in config json file
variable "cip_tenant" { type = bool }
variable "default_node_pool" { type = map(any) }
variable "node_pools" { type = any }
variable "azure_rbac_enabled" { 
   description = "Variable to determine if Azure AD RBAC authentication is enabled"
   type = bool
   default = false
}
variable "managed" {
   description = "Variable to determine if Azure Active Directory integration is managed"
   type = bool
   default = true
}
variable "role_based_access_control_enabled" {
   description = "Variable to determine if role based access control is enabled"
   type = bool
   default = false
}
variable "local_account_disabled" {
   description = "Optional variable to determine if local accounts are enabled"
   type = bool
   default = false
}

locals {
  azure_credentials = try(jsondecode(var.azure_sp_credentials_json), null)

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
