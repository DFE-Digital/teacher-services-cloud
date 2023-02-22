variable "hosted_zone" {
  type = map(any)
}

variable "tags" {
  type = map(string)
}

variable "delegation_name" {
  type = string
  default = null
}

variable "delegation_ns" {
  type = list(string)
  default = null
}
