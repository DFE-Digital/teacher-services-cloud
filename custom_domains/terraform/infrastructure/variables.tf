variable "hosted_zone" {
  type = map(any)
}

variable "tags" {
  type = map(string)
}

variable "delegation_name" {
  type    = string
  default = null
}

variable "delegation_ns" {
  type    = list(string)
  default = null
}

# Set via TF_VAR environment variable in the workflow
variable "azure_sp_credentials_json" {
  default = null
  type    = string
}

locals {
  azure_credentials = try(jsondecode(var.azure_sp_credentials_json), null)
}
