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
    for_each = each.value.delegations

    content {
      name = delegation.key
      service_delegation {
        name    = delegation.value["name"]
        actions = delegation.value["actions"]
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
    node_count     = 1
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.aks-subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone" "backing-services-dns-zones" {
  for_each = local.subnets

  name                = var.environment == var.config ? "${var.config}.internal.postgres.database.azure.com" : "${var.environment}.${var.config}.internal.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.cluster.name

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-vnet-links" {
  for_each = resource.azurerm_private_dns_zone.backing-services-dns-zones

  name                  = each.value.name
  resource_group_name   = data.azurerm_resource_group.cluster.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.vnet.id

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_resource_group" "backing_services_group" {
  name     = local.backing_services_resource_group_name
  location = data.azurerm_resource_group.cluster.location
  tags     = jsondecode(var.azure_tags)
}
