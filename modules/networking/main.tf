resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.lab_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
  # DNS is managed by the separate DNS-servers resource after Firewall creation.
  lifecycle {
    ignore_changes = [dns_servers]
  }
}
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.address_space, 10, 0)]
}
resource "azurerm_subnet" "agents" {
  name                            = "snet-agents"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [cidrsubnet(var.address_space, 8, 1)]
  default_outbound_access_enabled = false
  delegation {
    name = "managed-devops-pools"
    service_delegation {
      name    = "Microsoft.DevOpsInfrastructure/pools"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
resource "azurerm_subnet" "endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [cidrsubnet(var.address_space, 11, 16)]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Disabled"
}
resource "azurerm_network_security_group" "agents" {
  name                = "nsg-${var.lab_id}-agents"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  security_rule {
    name                       = "deny-unsolicited-inbound"
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
resource "azurerm_subnet_network_security_group_association" "agents" {
  subnet_id                 = azurerm_subnet.agents.id
  network_security_group_id = azurerm_network_security_group.agents.id
}
