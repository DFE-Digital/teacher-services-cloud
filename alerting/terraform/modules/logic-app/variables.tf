variable "name" {
  description = "Logic App name"
  type        = string
}

variable "environment" {
  type        = string
  description = "Current application environment"
}

variable "logic_app_type" {
  description = "Logic App type (Consumption or Standard)"
  type        = string
  default     = "Consumption"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}
