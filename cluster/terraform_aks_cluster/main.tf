data "azurerm_resource_group" "cluster" {
  name = var.resource_group_name
}

data "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = var.managed_identity_name
  resource_group_name = data.azurerm_resource_group.cluster.name
}

resource "azurerm_kubernetes_cluster" "main" {
  name                      = local.cluster_name
  location                  = data.azurerm_resource_group.cluster.location
  resource_group_name       = data.azurerm_resource_group.cluster.name
  node_resource_group       = local.node_resource_group_name
  dns_prefix                = local.dns_prefix
  kubernetes_version        = var.kubernetes_version
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.enable_azure_RBAC ? [1] : []

    content {
      managed                = true
      azure_rbac_enabled     = true
      admin_group_object_ids = [var.admin_group_id]
    }
  }
  local_account_disabled = var.enable_azure_RBAC

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.aks_system_logs.id
    msi_auth_for_monitoring_enabled = true
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
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.aks_control_plane.id]
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"

    load_balancer_profile {
      outbound_ip_address_ids = [azurerm_public_ip.egress-public-ip.id]
    }
  }

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

  timeouts {
    create = "180m"
    update = "180m"
    delete = "180m"
  }
}

resource "azurerm_kubernetes_cluster" "clone" {
  count = var.clone_cluster ? 1 : 0

  name                      = local.clone_cluster_name
  location                  = azurerm_kubernetes_cluster.main.location
  resource_group_name       = azurerm_kubernetes_cluster.main.resource_group_name
  node_resource_group       = local.clone_node_resource_group_name
  dns_prefix                = "${azurerm_kubernetes_cluster.main.dns_prefix}-clone"
  kubernetes_version        = azurerm_kubernetes_cluster.main.kubernetes_version
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.enable_azure_RBAC_clone ? [1] : []

    content {
      managed                = true
      azure_rbac_enabled     = true
      admin_group_object_ids = [var.admin_group_id]
    }
  }
  local_account_disabled = var.enable_azure_RBAC_clone

  default_node_pool {
    name                 = azurerm_kubernetes_cluster.main.default_node_pool[0].name
    node_count           = azurerm_kubernetes_cluster.main.default_node_pool[0].node_count
    vm_size              = azurerm_kubernetes_cluster.main.default_node_pool[0].vm_size
    vnet_subnet_id       = azurerm_subnet.aks-subnet-clone[0].id
    zones                = azurerm_kubernetes_cluster.main.default_node_pool[0].zones
    orchestrator_version = azurerm_kubernetes_cluster.main.default_node_pool[0].orchestrator_version
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.aks_control_plane.id]
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"

    load_balancer_profile {
      outbound_ip_address_ids = [azurerm_public_ip.egress-public-ip-clone[0].id]
    }
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
  resource_group_name = data.azurerm_resource_group.cluster.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_public_ip" "egress-public-ip-clone" {
  count               = var.clone_cluster ? 1 : 0
  name                = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-clone-egress-pip"
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle { ignore_changes = [tags] }
}

# resource "null_resource" "delayed_uncordon" {
#   # Trigger uncordon after node pool creation/updation

#  for_each = azurerm_kubernetes_cluster_node_pool.node_pools

#   triggers = {
#     node_pool_id = each.value.id
#   }

#   provisioner "local-exec" {
#     command = <<EOT
#       echo "Waiting for 10 minutes before uncordoning..."
#       sleep 120
#       NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
#       kubectl uncordon $NODE_NAME
#     EOT
#   }
# }
