output "container_app_fqdn" {
  description = "Managed HTTPS FQDN for the public Container App endpoint."
  value       = azurerm_container_app.application.latest_revision_fqdn
}

output "container_app_url" {
  description = "Managed HTTPS URL for the public Container App endpoint."
  value       = "https://${azurerm_container_app.application.latest_revision_fqdn}"
}

output "postgres_fqdn" {
  description = "Private PostgreSQL server FQDN used by the Container App."
  value       = azurerm_postgresql_flexible_server.database.fqdn
}

output "postgres_admin_password" {
  description = "Generated PostgreSQL administrator password, when one was generated."
  value       = local.postgres_admin_password
  sensitive   = true
}
