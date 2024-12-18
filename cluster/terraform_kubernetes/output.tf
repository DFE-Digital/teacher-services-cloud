output "welcome_app_url" {
  value = "https://${local.default_welcome_app_hostname}/"
}

output "ga_wif_config" {
  description = "Configuration for workflows of services declared in var.ga_wif_namespaces"

  value = { for n in keys(var.ga_wif_namespaces) :
    n => {
      client_id       = azurerm_user_assigned_identity.ga_wif[n].client_id
      tenant_id       = azurerm_user_assigned_identity.ga_wif[n].tenant_id
      subscription_id = data.azurerm_subscription.current.subscription_id
    }
  }
}
