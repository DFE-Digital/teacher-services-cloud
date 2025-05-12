resource "helm_release" "airbyte" {
  for_each = toset(var.airbyte_namespaces)

  name       = "airbyte-${each.key}"
  repository = "https://airbytehq.github.io/helm-charts"
  chart      = "airbyte"
  version    = var.airbyte_version
  namespace  = "${each.key}"

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

}
