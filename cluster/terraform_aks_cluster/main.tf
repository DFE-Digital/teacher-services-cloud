data "azurerm_resource_group" "cluster" {
  name = var.resource_group_name
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  node_resource_group = local.node_resource_group_name
  dns_prefix          = local.dns_prefix

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_system_logs.id
  }

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
