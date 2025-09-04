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
    name  = "global.jobs.kube.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
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
  # default for all storage below is "airbyte-storage"
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
  # deployment settings below
  # name                   cpu requests  cpu limits   mem requests   mem limit
  # webapp                    100m          500m          100Mi          100Mi
  # server                    200m          600m          750Mi         1500Mi
  # worker                    200m          600m          500Mi         1500Mi
  # workload-launcher         200m          600m          750Mi         1500Mi
  # temporal                  200m          500m          200Mi          500Mi
  # cron                      200m          600m          400Mi         1000Mi
  # connector-builder-server  200m          600m          300Mi          500Mi
  # workload-api-server       200m          600m          350Mi         1000Mi
  # total                    1500m         4600m         3350Mi         7600Mi
  #
  # token                     100m          200m           64Mi          256Mi
  # jobs                      250m             2          256Mi            2Gi
  #
  set {
    name  = "webapp.resources.limits.cpu"
    value = "500m"
    type  = "string"
  }
  set {
    name  = "webapp.resources.limits.memory"
    value = "100Mi"
    type  = "string"
  }
  set {
    name  = "webapp.resources.requests.cpu"
    value = "100m"
    type  = "string"
  }
  set {
    name  = "webapp.resources.requests.memory"
    value = "100Mi"
    type  = "string"
  }
  set {
    name  = "webapp.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "webapp.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "webapp.image.tag"
    value = "airbyte-webapp-1.5.1"
    type  = "string"
  }
  set {
    name  = "server.resources.limits.cpu"
    value = "600m"
    type  = "string"
  }
  set {
    name  = "server.resources.limits.memory"
    value = "1500Mi"
    type  = "string"
  }
  set {
    name  = "server.resources.requests.cpu"
    value = "200m"
    type  = "string"
  }
  set {
    name  = "server.resources.requests.memory"
    value = "750Mi"
    type  = "string"
  }
  set {
    name  = "server.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "server.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "server.image.tag"
    value = "airbyte-server-1.5.1"
    type  = "string"
  }
  set {
    name  = "worker.resources.limits.cpu"
    value = "600m"
    type  = "string"
  }
  set {
    name  = "worker.resources.limits.memory"
    value = "1500Mi"
    type  = "string"
  }
  set {
    name  = "worker.resources.requests.cpu"
    value = "200m"
    type  = "string"
  }
  set {
    name  = "worker.resources.requests.memory"
    value = "500Mi"
    type  = "string"
  }
  set {
    name  = "worker.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "worker.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "worker.image.tag"
    value = "airbyte-worker-1.5.1"
    type  = "string"
  }
  set {
    name  = "workload-launcher.resources.limits.cpu"
    value = "600m"
    type  = "string"
  }
  set {
    name  = "workload-launcher.resources.limits.memory"
    value = "1500Mi"
    type  = "string"
  }
  set {
    name  = "workload-launcher.resources.requests.cpu"
    value = "200m"
    type  = "string"
  }
  set {
    name  = "workload-launcher.resources.requests.memory"
    value = "750Mi"
    type  = "string"
  }
  set {
    name  = "workload-launcher.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "workload-launcher.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "workload-launcher.image.tag"
    value = "airbyte-workload-launcher-1.5.1"
    type  = "string"
  }
  set {
    name  = "temporal.resources.limits.cpu"
    value = "500m"
    type  = "string"
  }
  set {
    name  = "temporal.resources.limits.memory"
    value = "500Mi"
    type  = "string"
  }
  set {
    name  = "temporal.resources.requests.cpu"
    value = "200m"
    type  = "string"
  }
  set {
    name  = "temporal.resources.requests.memory"
    value = "200Mi"
    type  = "string"
  }
  set {
    name  = "temporal.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "temporal.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "temporal.image.tag"
    value = "temporalio-auto-setup-1.26"
    type  = "string"
  }
  set {
    name  = "cron.resources.limits.cpu"
    value = "600m"
    type  = "string"
  }
  set {
    name  = "cron.resources.limits.memory"
    value = "1000Mi"
    type  = "string"
  }
  set {
    name  = "cron.resources.requests.cpu"
    value = "200m"
    type  = "string"
  }
  set {
    name  = "cron.resources.requests.memory"
    value = "400Mi"
    type  = "string"
  }
  set {
    name  = "cron.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "cron.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "cron.image.tag"
    value = "airbyte-cron-1.5.1"
    type  = "string"
  }
  set {
    name  = "connector-builder-server.resources.limits.cpu"
    value = "600m"
    type  = "string"
  }
  set {
    name  = "connector-builder-server.resources.limits.memory"
    value = "500Mi"
    type  = "string"
  }
  set {
    name  = "connector-builder-server.resources.requests.cpu"
    value = "200m"
    type  = "string"
  }
  set {
    name  = "connector-builder-server.resources.requests.memory"
    value = "300Mi"
    type  = "string"
  }
  set {
    name  = "connector-builder-server.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "connector-builder-server.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "connector-builder-server.image.tag"
    value = "airbyte-connector-builder-server-1.5.1"
    type  = "string"
  }
  set {
    name  = "workload-api-server.resources.limits.cpu"
    value = "600m"
    type  = "string"
  }
  set {
    name  = "workload-api-server.resources.limits.memory"
    value = "1000Mi"
    type  = "string"
  }
  set {
    name  = "workload-api-server.resources.requests.cpu"
    value = "200m"
    type  = "string"
  }
  set {
    name  = "workload-api-server.resources.requests.memory"
    value = "350Mi"
    type  = "string"
  }
  set {
    name  = "workload-api-server.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "workload-api-server.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "workload-api-server.image.tag"
    value = "airbyte-workload-api-server-1.5.1"
    type  = "string"
  }
  set {
    name  = "airbyte-bootloader.nodeSelector.teacherservices\\.cloud/node_pool"
    value = "applications"
    type  = "string"
  }
  set {
    name  = "airbyte-bootloader.image.repository"
    value = "ghcr.io/dfe-digital/teacher-services-cloud"
    type  = "string"
  }
  set {
    name  = "airbyte-bootloader.image.tag"
    value = "airbyte-bootloader-1.5.1"
    type  = "string"
  }
}
