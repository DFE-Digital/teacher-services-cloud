# Set in config shell variables and used by Makefile
variable "environment" {}
variable "resource_prefix" {}
variable "resource_group_name" {}

# Set in config json file
variable "cip_tenant" { type = bool }
variable "namespaces" {}
variable "node_pools" {
    type = map(object({
        pool_name = string
        product_name = string //this needs to be a separate property to prevent destruction when changing node_pool tags
        node_count = number
        vm_size = string
    }))

    validation {
        condition = alltrue([for p in var.node_pools : length(p.pool_name) < 13])
        error_message = "The pool_name must be 12 characters or less."
    }

    //TO DO: establish naming convention for node pools
}

locals {
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
}
