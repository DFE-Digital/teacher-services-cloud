data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "key_vault" {
  name                = var.cluster_kv
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "dockerhub_username" {
  name         = "dockerhub-username"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "azurerm_key_vault_secret" "dockerhub_pat" {
  name         = "dockerhub-pat"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}


resource "azurerm_container_registry" "acr" {
  name                = "AcrCache${var.environment}Dockerhub"
  resource_group_name = data.azurerm_resource_group.cluster.name
  location            = data.azurerm_resource_group.cluster.location
  sku                 = "Standard"

  admin_enabled = false
}

resource "azapi_resource" "dockerhub_credential_set" {
  count = var.environment == "development" ? 1 : 0

  type      = "Microsoft.ContainerRegistry/registries/credentialSets@2025-11-01"
  name      = "dockerhub-creds"
  parent_id = azurerm_container_registry.acr.id

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      loginServer = "docker.io"

      authCredentials = [
        {
          name                     = "Credential1"
          usernameSecretIdentifier = data.azurerm_key_vault_secret.dockerhub_username.versionless_id
          passwordSecretIdentifier = data.azurerm_key_vault_secret.dockerhub_pat.versionless_id
        }
      ]
    }
  }
}

resource "azurerm_role_assignment" "acr_cache_kv_secrets_user" {
  count = var.environment == "development" ? 1 : 0

  scope                = data.azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"

  principal_id = azapi_resource.dockerhub_credential_set[0].identity[0].principal_id
}

resource "azapi_resource" "dockerhub_nginx_cache" {
  count = var.environment == "development" ? 1 : 0

  type      = "Microsoft.ContainerRegistry/registries/cacheRules@2025-11-01"
  name      = "dockerhub-nginx"
  parent_id = azurerm_container_registry.acr.id

  body = {
    properties = {
      sourceRepository        = "docker.io/library/nginx"
      targetRepository        = "dockerhub/library/nginx"
      credentialSetResourceId = azapi_resource.dockerhub_credential_set[0].id
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_cache_kv_secrets_user
  ]
}
