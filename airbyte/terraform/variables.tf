# Set in config shell variables and used by Makefile
variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "resource_prefix" { type = string }
variable "config" { type = string }
variable "cluster_kv" { type = string }
variable "cip_tenant" { type = bool }

variable "ingress_cert_name" {
  type    = string
  default = null
}

data "azurerm_client_config" "current" {}

data "environment_variables" "github_actions" {
  filter = "GITHUB_ACTIONS"
}

variable "cluster_short" {
  type        = string
  description = "Short name of the cluster configuration, e.g. dv, pt, ts, pd"
}

variable "airbyte_version" {
  default = "1.5.1"
  type    = string
}

variable "airbyte_namespaces" {
  description = "List of namespaces with Airbyte enabled"
  type        = list(string)
  default     = []
}

variable "azure_storage_mb" {
  type    = number
  default = 32768
}

variable "azure_storage_tier" {
  type        = string
  description = "Tier of storage used by the PostgreSQL Flexible Server. Possible values are P4, P6, P10, P15, P20, P30, P40, P50, P60, P70, P80. Defaults to Premium if not specified. The storage tier available depends on the azure_storage_mb value, see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server#storage_tier-defaults-based-on-storage_mb for details."
  default     = null
  validation {
    condition     = var.azure_storage_tier == null ? true : contains(["P4", "P6", "P10", "P15", "P20", "P30", "P40", "P50", "P60", "P70", "P80"], var.azure_storage_tier)
    error_message = "The azure_storage_tier must be one of: P4, P6, P10, P15, P20, P30, P40, P50, P60, P70, P80"
  }
}

variable "azure_sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

# variable "cluster_configuration_map" {
#   type = object({
#     resource_group_name = string,
#     resource_prefix     = string,
#     dns_zone_prefix     = optional(string),
#     cpu_min             = number
#   })
#   description = "Configuration map for the cluster"
# }

locals {
  cluster_name = (
    var.cip_tenant ?
    "${var.resource_prefix}-tsc-${var.environment}-aks" :
    "${var.resource_prefix}aks-tsc-${var.environment}"
  )

  default_ingress_cert_name = (var.environment == var.config ?
    "${var.environment}-teacherservices-cloud" :             # For non dev environments, config is the same as environment
    "${var.environment}-${var.config}-teacherservices-cloud" # Development environments have unique names but share the same config
  )
  cluster_cert_secret = (var.ingress_cert_name != null ?
    var.ingress_cert_name : # Override certificate name if required for this environment
    local.default_ingress_cert_name
  )

  kubelogin_github_actions_args = [
    "get-token",
    "--server-id",
    "6dae42f8-4368-4678-94ff-3960e28e3630" # See https://azure.github.io/kubelogin/concepts/aks.html
  ]
  kubelogin_azurecli_args = [
    "get-token",
    "--login",
    "azurecli",
    "--server-id",
    "6dae42f8-4368-4678-94ff-3960e28e3630"
  ]
  running_in_github_actions = contains(keys(data.environment_variables.github_actions.items), "GITHUB_ACTIONS")
  # If running in github actions, AAD_LOGIN_METHOD determines the login method, either workloadidentity or spn
  # If not, use azurecli explicitly as command line argument
  kubelogin_args = (local.running_in_github_actions ?
    local.kubelogin_github_actions_args :
    local.kubelogin_azurecli_args
  )

  cluster_sa_name = (var.environment == var.config ?
    var.cluster_short : # pt,ts or pd
    var.environment     # cluster1, cluster2, etc
  )

}
