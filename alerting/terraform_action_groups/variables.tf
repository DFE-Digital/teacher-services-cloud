# Set in config shell variables and used by Makefile
variable "environment" { type = string }
variable "resource_prefix" { type = string }

variable "alerting_resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "action_groups_to_hookup" {
  type        = map(any)
  description = "Map of action groups to connect up to logic app."
}
