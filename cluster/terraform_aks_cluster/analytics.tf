# Create Log Analytics workspace
resource "azurerm_log_analytics_workspace" "aks_system_logs" {
  name                = "${var.resource_prefix}-tsc-${var.environment}-log"
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_monitor_diagnostic_setting" "aks_system_logs" {
  name                       = "aks-system-logs"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_system_logs.id

  # In order to find the categories go to the json view on the diagnostics settings pane
  # It's currently set to this as default and can be expanded upon
  enabled_log {
    category = "kube-apiserver"

    retention_policy {
      enabled = true
      days    = 10
    }
  }
  enabled_log {
    category = "kube-audit-admin"

    retention_policy {
      enabled = true
      days    = 10
    }
  }
  enabled_log {
    category = "kube-controller-manager"

    retention_policy {
      enabled = true
      days    = 10
    }
  }
  enabled_log {
    category = "kube-scheduler"

    retention_policy {
      enabled = true
      days    = 10
    }
  }
  enabled_log {
    category = "cluster-autoscaler"

    retention_policy {
      enabled = true
      days    = 10
    }
  }
  enabled_log {
    category = "cloud-controller-manager"

    retention_policy {
      enabled = true
      days    = 10
    }
  }
  metric {
    category = "AllMetrics"
    enabled  = false
  }
}
