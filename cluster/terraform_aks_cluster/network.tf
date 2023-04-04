resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  location            = data.azurerm_resource_group.cluster.location
  resource_group_name = data.azurerm_resource_group.cluster.name
  address_space       = ["10.0.0.0/12"]

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_subnet" "aks-subnet" {
  name                 = "aks-snet"
  resource_group_name  = data.azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  # by default AKS uses 10.0.0.0/16 for its internal service CIDR range, this cannot overlap with the external subnet so we use 10.1.0.0/16
  address_prefixes = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "aks-subnet-clone" {
  count                = var.clone_cluster ? 1 : 0
  name                 = "aks-clone-snet"
  resource_group_name  = data.azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.3.0.0/16"]
}
