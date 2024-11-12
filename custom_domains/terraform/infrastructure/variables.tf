variable "hosted_zone" {
  type = map(any)
}

variable "delegation_name" {
  type    = string
  default = null
}

variable "delegation_ns" {
  type    = list(string)
  default = null
}

variable "deploy_default_records" {
  type        = bool
  description = "Let the module create the default zone records"
}
