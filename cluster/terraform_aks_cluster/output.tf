output "cluster_name" {
  value = local.cluster_name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}
