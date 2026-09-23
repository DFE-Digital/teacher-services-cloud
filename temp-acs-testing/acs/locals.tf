locals {
  name = "${var.name_prefix}-tsc-tt-acs"

  tags = merge({
    managed_by         = "terraform"
    workload           = "public-acs-private-postgres"
    Product            = "Teacher services cloud"
    "Service Offering" = "Teacher services cloud"
  }, var.tags)

  postgres_admin_password = coalesce(var.postgres_admin_password, random_password.postgres.result)
}
