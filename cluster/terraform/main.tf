data "azurerm_resource_group" "cluster" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  address_space       = ["10.0.0.0/12"]

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = "aks-snet"
  resource_group_name  = data.azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  # by default AKS uses 10.0.0.0/16 for it's internal service CIDR range, this cannot overlap with the external subnet so we use 10.1.0.0/16
  address_prefixes = ["10.1.0.0/16"]
}

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

resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  node_resource_group = local.node_resource_group_name
  dns_prefix          = local.dns_prefix

  default_node_pool {
    name           = "default"
    node_count     = var.default_node_pool.node_count
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.aks-subnet.id
    zones          = local.uk_south_availability_zones
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_kubernetes_cluster_node_pool" "node_pools" {
  for_each = var.node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D2_v2"
  enable_auto_scaling   = true
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  vnet_subnet_id        = azurerm_subnet.aks-subnet.id
  zones                 = local.uk_south_availability_zones
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
}
