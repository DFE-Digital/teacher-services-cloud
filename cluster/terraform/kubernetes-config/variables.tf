variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "config" { type = string }
variable "cluster_kv" { type = string }
variable "ingress_cert_name" {
  type    = string
  default = null
}
variable "namespaces" { type = list(string) }

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
