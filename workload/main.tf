locals {
  tags = {
    lab_id      = var.lab_id
    environment = "lab"
    managed_by  = "terraform"
    project     = "azure-private-build-agents-lab"
  }
}
resource "azurerm_virtual_network" "sample" {
  name                = "vnet-${var.lab_id}-sample"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
  tags                = local.tags
}
resource "azurerm_subnet" "sample" {
  name                            = "snet-sample"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.sample.name
  address_prefixes                = [cidrsubnet(var.vnet_address_space, 8, 0)]
  default_outbound_access_enabled = false
}
resource "azurerm_network_security_group" "sample" {
  name                = "nsg-${var.lab_id}-sample"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
  security_rule {
    name                       = "deny-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "sample" {
  subnet_id                 = azurerm_subnet.sample.id
  network_security_group_id = azurerm_network_security_group.sample.id
}
