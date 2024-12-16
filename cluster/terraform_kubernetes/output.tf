output "welcome_app_url" {
  value = "https://${local.default_welcome_app_hostname}/"
}

output "ga_wif_creds" {
  value = { for mi in azurerm_user_assigned_identity.ga_wif :
    mi.name => {
      client_id = mi.client_id
      tenant_id = mi.tenant_id
      subscription =
    }
  }
}
