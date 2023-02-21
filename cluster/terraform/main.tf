# Structure based on https://github.com/hashicorp/terraform-provider-kubernetes/tree/main/_examples/aks
# to ensure the AKS cluster and its configuration are create separately
# See: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#stacking-with-managed-kubernetes-cluster-resources

module "aks-cluster" {
  source              = "./aks-cluster"
  azure_tags          = var.azure_tags
  environment         = var.environment
  resource_prefix     = var.resource_prefix
  resource_group_name = var.resource_group_name
  config              = var.config
  cip_tenant          = var.cip_tenant
  default_node_pool   = var.default_node_pool
  node_pools          = var.node_pools
}

data "azurerm_kubernetes_cluster" "main" {
  depends_on          = [module.aks-cluster] # Refresh cluster state before reading
  name                = module.aks-cluster.cluster_name
  resource_group_name = var.resource_group_name
}

module "kubernetes-config" {
  depends_on                      = [module.aks-cluster] # Refresh cluster state before reading
  source                          = "./kubernetes-config"
  environment                     = var.environment
  resource_prefix                 = var.resource_prefix
  resource_group_name             = var.resource_group_name
  cluster_dns_resource_group_name = var.cluster_dns_resource_group_name
  cluster_dns_zone                = var.cluster_dns_zone
  cluster_kv                      = var.cluster_kv
  config                          = var.config
  ingress_cert_name               = var.ingress_cert_name
  namespaces                      = var.namespaces
}
