data "azurerm_resource_group" "cluster" {
  name = var.resource_group_name
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  node_resource_group = local.node_resource_group_name
  dns_prefix          = local.dns_prefix

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_kubernetes_cluster_node_pool" "tra-node-pool" {
  name                  = "tra"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  node_count            = 1
  vm_size               = "Standard_D2_v2"
  tags = {
    "Product" : "Refer Serious Misconduct"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "bat-node-pool" {
  name                  = "bat"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  node_count            = 1
  vm_size               = "Standard_D2_v2"
  tags = {
    "Product" : "Find postgraduate teacher training"
  }
}
