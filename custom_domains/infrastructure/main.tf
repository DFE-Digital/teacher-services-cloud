module "domains_infrastructure" {
  source      = "git::https://github.com/DFE-Digital/terraform-modules.git//domains/infrastructure"
  hosted_zone = var.hosted_zone
  tags        = var.tags
}
