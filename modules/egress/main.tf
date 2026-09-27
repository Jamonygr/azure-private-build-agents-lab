locals {
  organization = trimprefix(var.organization_url, "https://dev.azure.com/")
  allowed_https_fqdns = [
    "*.prod.manageddevops.microsoft.com",
    "rmprodbuilds.azureedge.net",
    "*.queue.core.windows.net",
    "download.agent.dev.azure.com",
    "dev.azure.com",
    "${local.organization}.visualstudio.com",
    "${local.organization}.services.visualstudio.com",
    "${local.organization}.vsblob.visualstudio.com",
    "${local.organization}.vssps.visualstudio.com",
    "vssps.dev.azure.com",
    "vsrm.dev.azure.com",
    "*.vsassets.io",
    "*.vsblob.vsassets.io",
    "login.microsoftonline.com",
    "management.azure.com",
    "graph.microsoft.com",
    "pas.windows.net",
    "management.core.windows.net",
    "releases.hashicorp.com",
    "registry.terraform.io",
    "checkpoint-api.hashicorp.com"
  ]
}
resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.lab_id}-firewall"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
resource "azurerm_firewall_policy" "this" {
  name                     = "fwpol-${var.lab_id}"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  sku                      = "Standard"
  threat_intelligence_mode = "Deny"
  dns {
    proxy_enabled = true
    servers       = ["168.63.129.16"]
  }
  tags = var.tags
}
resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "lab-egress"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200
  application_rule_collection {
    name     = "required-https"
    priority = 200
    action   = "Allow"
    rule {
      name              = "mdp-devops-azure-terraform"
      source_addresses  = ["*"]
      destination_fqdns = local.allowed_https_fqdns
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
  application_rule_collection {
    name     = "windows-platform"
    priority = 210
    action   = "Allow"
    rule {
      name                  = "windows-update"
      source_addresses      = ["*"]
      destination_fqdn_tags = ["WindowsUpdate"]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}
resource "azurerm_firewall" "this" {
  name                = "fw-${var.lab_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
  tags = var.tags
}
resource "azurerm_virtual_network_dns_servers" "this" {
  virtual_network_id = var.vnet_id
  dns_servers        = [azurerm_firewall.this.ip_configuration[0].private_ip_address]
}
resource "azurerm_route_table" "agents" {
  name                          = "rt-${var.lab_id}-agents"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags                          = var.tags
}
resource "azurerm_route" "default" {
  name                   = "default-through-firewall"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.agents.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
}
resource "azurerm_subnet_route_table_association" "agents" {
  subnet_id      = var.agent_subnet_id
  route_table_id = azurerm_route_table.agents.id
}
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "firewall-logs"
  target_resource_id             = azurerm_firewall.this.id
  log_analytics_workspace_id     = var.workspace_resource_id
  log_analytics_destination_type = "Dedicated"
  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}
