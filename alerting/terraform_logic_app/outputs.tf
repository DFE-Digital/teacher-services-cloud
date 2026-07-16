output "logic_app_id" {
  value = azapi_resource.consumption.id
}

output "logic_app_name" {
  value = azapi_resource.consumption.name
}

output "resource_group_name" {
  value = var.alerting_resource_group_name
}
