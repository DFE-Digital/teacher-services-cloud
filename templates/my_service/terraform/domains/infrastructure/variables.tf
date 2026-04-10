variable "hosted_zone" {
  type = map(any)
}

variable "deploy_default_records" {
  type    = bool
  default = true
}
