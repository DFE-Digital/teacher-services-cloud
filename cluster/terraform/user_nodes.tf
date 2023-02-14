resource "azurerm_kubernetes_cluster_node_pool" "userpools" {
  for_each                 = try(var.node_pools, {})
  name                     = each.key
  mode                     = try(each.value.mode, "User")
  kubernetes_cluster_id    = azurerm_kubernetes_cluster.main.id 
  orchestrator_version     = try(each.value.orchestrator_version, null)
  vm_size                  = try(each.value.vm_size, null)
  os_disk_size_gb          = try(each.value.os_disk_size_gb, null)
  os_disk_type             = try(each.value.os_disk_type, null)
  node_count               = try(each.value.node_count, 1)
  min_count                = try(each.value.min_count, null)
  max_count                = try(each.value.max_count, null)
  priority                 = try(each.value.priority, null)
  eviction_policy          = try(each.value.eviction_policy, null)
  vnet_subnet_id           = try(each.value.subnet_id, null)
  zones                    = try(each.value.zones, null)
  enable_auto_scaling      = try(each.value.enable_auto_scaling, false)
  enable_node_public_ip    = try(each.value.enable_node_public_ip, false)
  node_public_ip_prefix_id = try(each.value.node_public_ip_prefix_id, null)
  node_labels              = try(each.value.node_labels, null)
  node_taints              = try(each.value.node_taints, null)
  enable_host_encryption   = try(each.value.enable_host_encryption, false)
  max_pods                 = try(each.value.max_pods, null)
}
