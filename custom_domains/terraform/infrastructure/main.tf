module "domains_infrastructure" {
  source      = "git::https://github.com/DFE-Digital/terraform-modules.git//domains/infrastructure?ref=testing"
  hosted_zone = var.hosted_zone
  tags        = var.tags
}

resource "azurerm_dns_ns_record" "dev_ns_record" {
  count = var.delegation_name != null ? 1 : 0

  name                = var.delegation_name
  zone_name           = keys(var.hosted_zone)[0]
  resource_group_name = var.hosted_zone[keys(var.hosted_zone)[0]].resource_group_name
  records             = var.delegation_ns
  ttl                 = 300
}

module "dns_records" {
  source      = "git::https://github.com/DFE-Digital/terraform-modules.git//dns/records?ref=testing"
  hosted_zone = var.hosted_zone
}
