# Set in config shell variables and used by Makefile
variable "environment" { type = string }
variable "resource_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "cluster_kv" { type = string }

variable "alerting_resource_group_name" {
  type        = string
  description = "Name of the resource group for logic app and alerting resources."
}
