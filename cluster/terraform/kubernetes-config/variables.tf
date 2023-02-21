variable "environment" {}
variable "resource_group_name" {}
variable "resource_prefix" {}
variable "config" {}

variable "cluster_dns_resource_group_name" { default = null }
variable "cluster_dns_zone" {
  description = "The name of the DNS zone containing A records pointing to the ingress public IPs.  This is only used for the development environment"
  default     = null
  type        = string
}
variable "cluster_kv" {}
variable "ingress_cert_name" {
  type    = string
  default = null
}
variable "namespaces" {}

locals {
  default_ingress_cert_name = (var.environment == var.config ?
    "${var.environment}-teacherservices-cloud" :             # For non dev environments, config is the same as environment
    "${var.environment}-${var.config}-teacherservices-cloud" # Development environments have unique names but share the same config
  )
  cluster_cert_secret = (var.ingress_cert_name != null ?
    var.ingress_cert_name : # Override certificate name if required for this environment
    local.default_ingress_cert_name
  )
}
