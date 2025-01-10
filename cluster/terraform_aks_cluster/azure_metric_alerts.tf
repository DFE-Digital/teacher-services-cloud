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

data "azurerm_subscription" "current" {}

resource "azurerm_monitor_metric_alert" "port_exhaustion" {
  name                = "${var.resource_prefix}-tsc-${var.environment}-port-exhaustion"
  resource_group_name = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-rg"
  scopes              = ["/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_prefix}-tsc-aks-nodes-${var.environment}-rg/providers/Microsoft.Network/loadBalancers/kubernetes"]
  severity            = 1
  criteria {
    metric_namespace = "microsoft.network/loadbalancers"
    metric_name      = "SnatConnectionCount"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
    dimension {
      name     = "ConnectionState"
      operator = "Include"
      values   = ["failed"]
    }
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.main.id
  }

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_monitor_metric_alert" "high_port_usage" {
  name                = "${var.resource_prefix}-tsc-${var.environment}-high-port-usage"
  resource_group_name = "${var.resource_prefix}-tsc-aks-nodes-${var.environment}-rg"
  scopes              = ["/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_prefix}-tsc-aks-nodes-${var.environment}-rg/providers/Microsoft.Network/loadBalancers/kubernetes"]
  severity            = 2
  criteria {
    metric_namespace = "microsoft.network/loadbalancers"
    metric_name      = "UsedSnatPorts"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 900
    dimension {
      name     = "BackendIPAddress"
      operator = "Include"
      values   = ["*"]
    }
    dimension {
      name     = "ProtocolType"
      operator = "Include"
      values   = ["TCP"]
    }
  }

  action {
    action_group_id = data.azurerm_monitor_action_group.main.id
  }

  lifecycle { ignore_changes = [tags] }
}
