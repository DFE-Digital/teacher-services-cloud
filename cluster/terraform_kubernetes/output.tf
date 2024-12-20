output "welcome_app_url" {
  value = "https://${local.default_welcome_app_hostname}/"
}

output "ga_wif_config" {
  description = "Configuration for workflows of services declared in var.ga_wif_namespaces"

  value = { for m in keys(var.ga_wif_managed_id) :
    m => {
      managed_id_name = azurerm_user_assigned_identity.ga_wif[m].name
      client_id       = azurerm_user_assigned_identity.ga_wif[m].client_id
      tenant_id       = azurerm_user_assigned_identity.ga_wif[m].tenant_id
      subscription_id = data.azurerm_subscription.current.subscription_id
    }
  }
}
