data "azurerm_key_vault_secret" "statuscake_secret" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
  name         = "STATUSCAKE-API-TOKEN"
}

resource "statuscake_uptime_check" "alert" {
  for_each = var.clone_cluster ? {} : var.statuscake_alerts

  name           = each.value.website_name
  check_interval = each.value.check_rate
  confirmation   = 2
  trigger_rate   = 0
  regions        = ["london", "dublin"]
  contact_groups = each.value.contact_group

  http_check {
    follow_redirects = true
    timeout          = 40
    request_method   = "HTTP"
    status_codes = [
      "204",
      "205",
      "206",
      "303",
      "400",
      "401",
      "403",
      "404",
      "405",
      "406",
      "408",
      "410",
      "413",
      "444",
      "429",
      "494",
      "495",
      "496",
      "499",
      "500",
      "501",
      "502",
      "503",
      "504",
      "505",
      "506",
      "507",
      "508",
      "509",
      "510",
      "511",
      "521",
      "522",
      "523",
      "524",
      "520",
      "598",
      "599"
    ]
  }

  monitored_resource {
    address = each.value.website_url
  }
}

resource "statuscake_ssl_check" "ingress" {
  for_each = var.clone_cluster ? {} : var.statuscake_ssl_alerts

  check_interval = each.value.check_rate
  user_agent     = "terraform managed SSL check"

  alert_config {
    alert_at    = [7, 14, 21]
    on_broken   = false
    on_expiry   = true
    on_mixed    = false
    on_reminder = true
  }

  contact_groups = each.value.contact_group

  monitored_resource {
    address = each.value.website_url
  }
}
