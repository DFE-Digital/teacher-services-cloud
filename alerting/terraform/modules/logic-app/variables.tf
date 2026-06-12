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

variable "publisher_email" {
  type        = string
  description = "APIM publisher email"
  default = "robert.gwenter@education.gov.uk"
}

variable "subscription_id" {
  type        = string
  description = "Primary Subscription Id"
}
