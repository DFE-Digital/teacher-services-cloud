resource "helm_release" "airbyte" {
  for_each = toset(var.airbyte_namespaces)

  name       = "airbyte-${each.key}"
  repository = "https://airbytehq.github.io/helm-charts"
  chart      = "airbyte"
  version    = var.airbyte_version
  namespace  = "${each.key}"

  depends_on = [
    kubernetes_secret.airbyte_db_secrets
  ]

  # # The first part of the name with simple dots is the keys path in the values.yml file e.g. global.serviceAccountName.annotations
  # # The last part is the final key e.g. azure\\.workload\\.identity/client-id
  # # It may have double escaped dots if the key contains dots e.g. \\.
  # # The corresponding value is in the "value" argument
  # # https://github.com/airbytehq/airbyte-platform/blob/main/charts/airbyte/values.yaml
  set {
    name  = "global.serviceAccountName"
    value = "airbyte-admin"
    type  = "string"
  }
  set {
    name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
    value = data.azurerm_user_assigned_identity.gcp_wif["${each.key}"].client_id
    type  = "auto"
  }
  set {
    name  = "global.env_vars.GOOGLE_EXTERNAL_ACCOUNT_ALLOW_EXECUTABLES"
    value = "1"
    type  = "auto"
  }
  set {
    name  = "global.jobs.resources.limits.cpu"
    value = "2"
    type  = "auto"
  }
  set {
    name  = "global.jobs.resources.limits.memory"
    value = "2Gi"
    type  = "string"
  }
  set {
    name  = "global.jobs.resources.requests.cpu"
    value = "250m"
    type  = "string"
  }
  set {
    name  = "global.jobs.resources.requests.memory"
    value = "256Mi"
    type  = "string"
  }
  set {
    name  = "global.jobs.kube.labels.azure\\.workload\\.identity/use"
    value = "true"
    type  = "auto"
  }
  set {
    name  = "global.auth.enabled"
    value = "true"
    type  = "auto"
  }
  set {
    name  = "global.auth.instanceAdmin.secretName"
    value = "airbyte-auth-secrets"
    type  = "string"
  }
  set {
    name  = "global.auth.instanceAdmin.passwordSecretKey"
    value = "instance-admin-password"
    type  = "string"
  }
  # set {
  #   name  = "global.auth.instanceAdmin.emailSecretKey"
  #   value = "instance-admin-email"
  #   type  = "string"
  # }
  # set {
  #   name  = "minio.storage.volumeClaimValue"
  #   value = "4000Mi"
  #   type  = "auto"
  # }
  set {
    name  = "global.env_vars.TEMPORAL_HISTORY_RETENTION_IN_DAYS"
    value = "7"
    type  = "auto"
  }
  set {
    name  = "global.env_vars.AIRBYTE_CLEANUP_JOB_ENABLED"
    value = "true"
    type  = "auto"
  }
  set {
    name  = "global.env_vars.AIRBYTE_CLEANUP_JOB_RETENTION_DAYS"
    value = "7"
    type  = "auto"
  }

  set {
    name  = "global.storage.type"
    value = "Azure"
    type  = "string"
  }
  # default for all below is "airbyte-storage"
  set {
    name  = "global.storage.bucket.log"
    value = "airbyte-bucket"
    type  = "string"
  }
  set {
    name  = "global.storage.bucket.state"
    value = "airbyte-bucket"
    type  = "string"
  }
  set {
    name  = "global.storage.bucket.workloadOutput"
    value = "airbyte-bucket"
    type  = "string"
  }
  set {
    name  = "global.storage.azure.connectionString"
    value = azurerm_storage_account.airbyte["${each.key}"].primary_connection_string
    type  = "string"
  }
  set {
    name  = "postgresql.enabled"
    value = "false"
    type  = "auto"
  }
  set {
    name  = "global.database.type"
    value = "external"
    type  = "string"
  }
  set {
    name  = "global.database.secretName"
    value = "airbyte-db-secrets"
    type  = "string"
  }
  set {
    name  = "global.database.host"
    value = "${var.resource_prefix}-ab-${each.key}-psql.postgres.database.azure.com"
    type  = "string"
  }
  set {
    name  = "global.database.port"
    value = "5432"
    type  = "auto"
  }
  set {
    name  = "global.database.database"
    value = "tsc_${each.key}"
    type  = "string"
  }
  set {
    name  = "global.database.userSecretKey"
    value = "DATABASE_USER"
    type  = "string"
  }
  set {
    name  = "global.database.passwordSecretKey"
    value = "DATABASE_PASSWORD"
    type  = "string"
  }

}
