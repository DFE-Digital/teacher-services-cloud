
resource "azurerm_api_management" "apim" {
  name                = "s189d01-tsc-apim-alerts-secure"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  publisher_name      = "DFE-TSC"
  publisher_email     = var.publisher_email
  sku_name            = "Consumption_0"

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_api_management_api" "alerts_api" {
  name                = "s189d01-tsc-alerts-api"
  resource_group_name = data.azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Alerts API"
  path                = "alerts"
  protocols           = ["https"]
}

resource "azurerm_api_management_api_operation" "post_alert" {
  operation_id        = "post-alert"
  api_name            = azurerm_api_management_api.alerts_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.this.name
  display_name        = "Post Alert"
  method              = "POST"
  url_template        = "/"
}

resource "azurerm_api_management_api_operation_policy" "policy" {
  api_name            = azurerm_api_management_api.alerts_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.this.name
  operation_id        = azurerm_api_management_api_operation.post_alert.operation_id
#${local.logic_app_base_url}
  xml_content = <<XML
<!--
    - Policies are applied in the order they appear.
    - Position <base/> inside a section to inherit policies from the outer scope.
    - Comments within policies are not preserved.
-->
<!-- Add policies as children to the <inbound>, <outbound>, <backend>, and <on-error> elements -->
<policies>
    <!-- Throttle, authorize, validate, cache, or transform the requests -->
    <inbound>
        <base />
        <set-backend-service id="apim-generated-policy" backend-id="LogicApp_s189d01-tsc-logic-app-test01_s189d01_79328b78d2455278c3bb29405bac60b9" />
        <set-method id="apim-generated-policy">POST</set-method>
        <rewrite-uri id="apim-generated-policy" template="/When_an_HTTP_request_is_received/paths/invoke/?api-version=2016-06-01&amp;sp=/triggers/When_an_HTTP_request_is_received/run&amp;sv=1.0&amp;sig={{s189d01-tsc-alerts-api_post-alert_6a0efd5623311d63195f3542}}" />
        <set-header id="apim-generated-policy" name="Ocp-Apim-Subscription-Key" exists-action="delete" />
    </inbound>
    <!-- Control if and how the requests are forwarded to services  -->
    <backend>
        <base />
    </backend>
    <!-- Customize the responses -->
    <outbound>
        <base />
    </outbound>
    <!-- Handle exceptions and customize error responses  -->
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

/*
resource "azurerm_api_management_named_value" "secret" {
  name                = "apim-shared-secret"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.this.name
  display_name        = "apim-shared-secret"

  value_from_key_vault {
    secret_id = azurerm_key_vault_secret.apim_secret.id
  }
}
*/
