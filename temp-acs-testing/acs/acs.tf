resource "azurerm_container_app_environment" "main" {
  name                           = "${local.name}-env"
  location                       = azurerm_resource_group.main.location
  resource_group_name            = azurerm_resource_group.main.name
  infrastructure_subnet_id       = azurerm_subnet.container_app.id
  internal_load_balancer_enabled = false
  tags                           = local.tags
}

resource "azurerm_container_app" "application" {
  name                         = "${local.name}-app"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  secret {
    name  = "database-password"
    value = local.postgres_admin_password
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "application"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = "${var.container_memory_gb}Gi"

      env {
        name  = "DATABASE_HOST"
        value = azurerm_postgresql_flexible_server.database.fqdn
      }

      env {
        name  = "DATABASE_NAME"
        value = azurerm_postgresql_flexible_server_database.application.name
      }

      env {
        name  = "DATABASE_USER"
        value = var.postgres_admin_username
      }

      env {
        name        = "DATABASE_PASSWORD"
        secret_name = "database-password"
      }

      env {
        name  = "DATABASE_PORT"
        value = "5432"
      }

      env {
        name  = "DATABASE_SSLMODE"
        value = "require"
      }
    }
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = var.container_port
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [
    azurerm_postgresql_flexible_server_database.application
  ]
}
