# Set via TF_VAR environment variable in the workflow
variable "azure_sp_credentials_json" {
  default = null
  type    = string
}

# Set in config shell variables and used by Makefile
variable "environment" {}
variable "resource_group_name" {}
variable "resource_prefix" {}
variable "azure_tags" { type = string }

# Set in config json file
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
variable "cip_tenant" { type = bool }
variable "namespaces" {}
variable "default_node_pool" { type = map(any) }
variable "node_pools" { type = map(any) }

locals {
  azure_credentials = try(jsondecode(var.azure_sp_credentials_json), null)
}
