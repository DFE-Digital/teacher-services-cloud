
resource "kubernetes_secret" "airbyte_db_secrets" {
  for_each = toset(var.airbyte_namespaces)

  metadata {
    name      = "airbyte-db-secrets"
    namespace = "${each.key}"
  }

  data = {
    DATABASE_USER = module.postgres["${each.key}"].username
    DATABASE_PASSWORD = module.postgres["${each.key}"].password
    DATABASE_URL = module.postgres["${each.key}"].url
  }

}

module "postgres" {
  for_each = toset(var.airbyte_namespaces)
  source = "./vendor/modules/aks//aks/postgres"

  namespace                   = "${each.key}"
  environment                 = "${each.key}"
  azure_resource_prefix       = var.resource_prefix
  service_name                = "airbyte"
  service_short               = "tsc"
  config_short                = "${var.environment}-bs"
  cluster_configuration_map   = module.cluster_data.configuration_map
  use_azure                   = "true"
  azure_enable_monitoring     = "false"
  azure_enable_backup_storage = "false"
  azure_extensions            = ["btree_gin"]
  server_version              = "16"
  azure_sku_name              = var.azure_sku_name

  azure_enable_high_availability = "false"
  azure_name_override = "${var.resource_prefix}-ab-${each.key}-psql"
}
