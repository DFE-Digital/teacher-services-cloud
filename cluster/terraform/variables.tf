# Set in config shell variables and used by Makefile
variable "environment" {}
variable "resource_prefix" {}
variable "resource_group_name" {}
variable "cluster_dns_resource_group_name" { default = null }
variable "cluster_dns_zone" { default = null }

# Set in config json file
variable "cip_tenant" { type = bool }
variable "namespaces" {}

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
