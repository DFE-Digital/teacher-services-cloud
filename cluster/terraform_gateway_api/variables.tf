variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "resource_prefix" { type = string }
variable "config" { type = string }

variable "cip_tenant" { type = bool }

variable "traefik_controller_version" {
  description = "Version of Traefik controller to use with K8S API-Gateway"
  type        = string
  default     = "1.14.0"
}

variable "traefik_version" {
  description = "Version of Traefik"
  type        = string
  default     = "39.0.4"
}

variable "gateway_api_version" {
  description = "Version of Gateway API"
  type        = string
  default     = "v1.4.0"
}

variable "ingress_nginx_memory" {
  description = "memory limit for nginx pods"
  type        = string
  default     = "512Mi"
}

data "environment_variables" "github_actions" {
  filter = "GITHUB_ACTIONS"
}
