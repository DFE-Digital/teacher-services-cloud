# Set in config shell variables and used by Makefile
variable "azure_sp_credentials_json" {
  default = null
  type    = string
}
variable "environment" {}
variable "resource_prefix" {}
variable "resource_group_name" {}
variable "cluster_dns_resource_group_name" { default = null }
variable "cluster_dns_zone" { default = null }
variable "cluster_kv" {}
variable "config" {}


# Set in config json file
variable "cip_tenant" { type = bool }
variable "namespaces" {}

locals {
  azure_credentials = try(jsondecode(var.azure_sp_credentials_json), null)
  environment       = var.environment == "" ? var.config : "${var.environment}-${var.config}"
  cluster_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-${local.environment}-aks" :
    "${var.resource_prefix}aks-tsc-${local.environment}"
  )
  node_resource_group_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-aks-nodes-${local.environment}-rg" :
    "${var.resource_prefix}rg-tsc-aks-nodes-${local.environment}"
  )
  dns_prefix          = "${var.resource_prefix}-tsc-${local.environment}"
  cluster_cert_secret = "${local.environment}-teacherservices-cloud"
}
