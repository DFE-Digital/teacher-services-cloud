output "logic_app_id" {
  value = coalesce(
    try(azurerm_logic_app_workflow.consumption[0].id, null),
    try(azurerm_logic_app_standard.standard[0].id, null)
  )
}

output "logic_app_name" {
  value = var.name
}

output "resource_group_name" {
  value = var.resource_group_name
}
