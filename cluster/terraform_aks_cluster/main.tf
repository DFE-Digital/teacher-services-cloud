data "azurerm_resource_group" "cluster" {
  name = var.resource_group_name
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  node_resource_group = local.node_resource_group_name
  dns_prefix          = local.dns_prefix
  kubernetes_version  = var.kubernetes_version

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_system_logs.id
  }

  default_node_pool {
    name                 = "default"
    node_count           = var.default_node_pool.node_count
    vm_size              = "Standard_D2_v2"
    vnet_subnet_id       = azurerm_subnet.aks-subnet.id
    zones                = local.uk_south_availability_zones
    orchestrator_version = var.default_node_pool.orchestrator_version
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"

    load_balancer_profile {
      outbound_ip_address_ids = [azurerm_public_ip.egress-public-ip.id]
    }
  }

  # role_based_access_control_enabled = var.rbac_enabled

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.rbac_enabled ? [1] : []
    content {
       azure_rbac_enabled = true
       managed            = true
       admin_group_object_ids = ["5e2b27e5-82a6-40ac-aecf-7fb363c22005"]
    }
  }

  local_account_disabled = var.rbac_enabled ? false : true

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_kubernetes_cluster_node_pool" "node_pools" {
  for_each = var.node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = try(each.value.vm_size, "Standard_D2_v2")
  enable_auto_scaling   = true
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  orchestrator_version  = each.value.orchestrator_version
  vnet_subnet_id        = azurerm_subnet.aks-subnet.id
  zones                 = local.uk_south_availability_zones
  node_labels           = try(each.value.node_labels, {})
}

resource "azurerm_kubernetes_cluster" "clone" {
  count = var.clone_cluster ? 1 : 0

  name                = local.clone_cluster_name
  location            = azurerm_kubernetes_cluster.main.location
  resource_group_name = azurerm_kubernetes_cluster.main.resource_group_name
  node_resource_group = local.clone_node_resource_group_name
  dns_prefix          = "${azurerm_kubernetes_cluster.main.dns_prefix}-clone"
  kubernetes_version  = azurerm_kubernetes_cluster.main.kubernetes_version

  default_node_pool {
    name                 = azurerm_kubernetes_cluster.main.default_node_pool[0].name
    node_count           = azurerm_kubernetes_cluster.main.default_node_pool[0].node_count
    vm_size              = azurerm_kubernetes_cluster.main.default_node_pool[0].vm_size
    vnet_subnet_id       = azurerm_subnet.aks-subnet-clone[0].id
    zones                = azurerm_kubernetes_cluster.main.default_node_pool[0].zones
    orchestrator_version = azurerm_kubernetes_cluster.main.default_node_pool[0].orchestrator_version
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_kubernetes_cluster_node_pool" "node_pools_clone" {
  for_each = var.clone_cluster ? var.node_pools : {}

  name                  = "${each.key}clone"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.clone[0].id
  vm_size               = try(each.value.vm_size, "Standard_D2_v2")
  enable_auto_scaling   = true
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  orchestrator_version  = each.value.orchestrator_version
  vnet_subnet_id        = azurerm_subnet.aks-subnet-clone[0].id
  zones                 = local.uk_south_availability_zones
  node_labels           = try(each.value.node_labels, {})
}

resource "azurerm_public_ip" "egress-public-ip" {
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-egress-pip"
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = local.node_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}
