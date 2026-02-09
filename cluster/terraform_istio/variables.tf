# Set in config shell variables and used by Makefile
variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "resource_prefix" { type = string }
variable "config" { type = string }

variable "cip_tenant" { type = bool }

variable "istio_version" {
  description = "Version of the ingress-nginx helm chart to use with istio"
  type        = string
  default     = "1.28.2"
}


variable "istio_gateway_pod_memory" {
  description = "memory limit for istio gateway pods"
  type        = string
  default     = "512Mi"
}

data "environment_variables" "github_actions" {
  filter = "GITHUB_ACTIONS"
}
