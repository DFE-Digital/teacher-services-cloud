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
  }
  enabled_log {
    category = "kube-audit-admin"
  }
  enabled_log {
    category = "kube-controller-manager"
  }
  enabled_log {
    category = "kube-scheduler"
  }
  enabled_log {
    category = "cluster-autoscaler"
  }
  enabled_log {
    category = "cloud-controller-manager"
  }
  metric {
    category = "AllMetrics"
    enabled  = false
  }
}

# Using a data collection rule to change the Container Insights data collection settings
# see https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-data-collection-dcr?tabs=cli

resource "azurerm_monitor_data_collection_rule" "aks" {
  name                = "${var.resource_prefix}-tsc-${var.environment}-dcr"
  resource_group_name = data.azurerm_resource_group.cluster.name
  location            = data.azurerm_resource_group.cluster.location

  lifecycle { ignore_changes = [tags] }

  destinations {
    log_analytics {
      name                  = "${var.resource_prefix}-tsc-${var.environment}-log-analytics-destination"
      workspace_resource_id = azurerm_log_analytics_workspace.aks_system_logs.id
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["${var.resource_prefix}-tsc-${var.environment}-log-analytics-destination"]
  }

  data_sources {
    extension {
      name = "ContainerInsightsExtension"
      # see https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-transformations#data-sources
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = var.ci_collection_interval
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks" {
  name                    = "${var.resource_prefix}-tsc-${var.environment}-dcr-assoc"
  target_resource_id      = azurerm_kubernetes_cluster.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks.id
}
