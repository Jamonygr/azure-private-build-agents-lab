resource "azurerm_storage_account" "state" {
  name                              = "st${var.lab_id}${var.suffix}"
  location                          = var.location
  resource_group_name               = var.resource_group_name
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  public_network_access             = "Disabled"
  shared_access_key_enabled         = false
  allow_nested_items_to_be_public   = false
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true
  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
  }
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
  tags = var.tags
}
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
resource "azurerm_key_vault" "this" {
  name                            = "kv-${var.lab_id}-${var.suffix}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  tenant_id                       = var.tenant_id
  sku_name                        = "standard"
  rbac_authorization_enabled      = true
  public_network_access_enabled   = false
  purge_protection_enabled        = true
  soft_delete_retention_days      = 7
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  network_acls {
    bypass         = "None"
    default_action = "Deny"
  }
  tags = var.tags
}
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                 = "link-${var.lab_id}-blob"
  private_dns_zone_id  = azurerm_private_dns_zone.blob.id
  virtual_network_id   = var.vnet_id
  registration_enabled = false
  tags                 = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                 = "link-${var.lab_id}-vault"
  private_dns_zone_id  = azurerm_private_dns_zone.vault.id
  virtual_network_id   = var.vnet_id
  registration_enabled = false
  tags                 = var.tags
}
resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${var.lab_id}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.endpoint_subnet_id
  private_service_connection {
    name                           = "blob"
    private_connection_resource_id = azurerm_storage_account.state.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
  tags = var.tags
}
resource "azurerm_private_endpoint" "vault" {
  name                = "pe-${var.lab_id}-vault"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.endpoint_subnet_id
  private_service_connection {
    name                           = "vault"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }
  tags = var.tags
}
resource "azurerm_monitor_diagnostic_setting" "vault" {
  name                           = "vault-audit"
  target_resource_id             = azurerm_key_vault.this.id
  log_analytics_workspace_id     = var.workspace_resource_id
  log_analytics_destination_type = "Dedicated"
  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}
resource "azurerm_monitor_diagnostic_setting" "blob" {
  name                           = "blob-audit"
  target_resource_id             = "${azurerm_storage_account.state.id}/blobServices/default"
  log_analytics_workspace_id     = var.workspace_resource_id
  log_analytics_destination_type = "Dedicated"
  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "Transaction"
  }
}
