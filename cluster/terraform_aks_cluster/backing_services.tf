resource "azurerm_subnet" "backing-service-subnets" {
  for_each = local.subnets

  name                 = each.key
  resource_group_name  = data.azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value.cidr_range]

  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", {}) != {} ? [1] : []

    content {
      name = lookup(each.value.delegation, "name", null)
      service_delegation {
        name    = lookup(each.value.delegation.service-delegation, "name", null)
        actions = lookup(each.value.delegation.service-delegation, "actions", null)
      }
    }
  }
}

resource "azurerm_private_dns_zone" "backing-services-privatelink-dns-zones" {
  for_each = toset(local.privatelink_dns_zone_names)

  name                = each.value
  resource_group_name = azurerm_resource_group.backing_services_group.name

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-vnet-links" {
  for_each = resource.azurerm_private_dns_zone.backing-services-privatelink-dns-zones

  name                  = each.value.name
  resource_group_name   = azurerm_resource_group.backing_services_group.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.vnet.id

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone" "backing-services-custom-dns-zones" {
  for_each = toset(local.custom_dns_zone_name_suffixes)

  name                = var.environment == var.config ? "${var.config}.${each.value}" : "${var.environment}.${var.config}.${each.value}"
  resource_group_name = azurerm_resource_group.backing_services_group.name

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "custom-dns-vnet-links" {
  for_each = resource.azurerm_private_dns_zone.backing-services-custom-dns-zones

  name                  = each.value.name
  resource_group_name   = azurerm_resource_group.backing_services_group.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.vnet.id

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_resource_group" "backing_services_group" {
  name     = local.backing_services_resource_group_name
  location = data.azurerm_resource_group.cluster.location
  tags     = jsondecode(var.azure_tags)

  lifecycle { ignore_changes = [tags] }
}
