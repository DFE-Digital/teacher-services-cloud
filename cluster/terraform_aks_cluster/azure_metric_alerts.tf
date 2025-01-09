data "azurerm_monitor_action_group" "main" {
  resource_group_name = local.monitoring_resource_group
  name                = local.monitor_action_group_name
}

resource "azurerm_monitor_metric_alert" "node_availability" {
  name                = "${var.resource_prefix}-tsc-${var.environment}-nodes-capacity"
  resource_group_name = local.monitoring_resource_group
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = "Action will be triggered when number of available nodes is less than ${local.required_available_nodes}"
  window_size         = "PT5M"
  frequency           = "PT1M"

  criteria {
    metric_namespace = "microsoft.containerservice/managedclusters"
    metric_name      = "kube_node_status_condition"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = local.node_threshold

    dimension {
      name     = "status2" # References the second status dimension available in the monitor metric
      operator = "Include"
      values   = ["Ready"]
    }
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.main.id
  }

  lifecycle { ignore_changes = [tags] }
}
