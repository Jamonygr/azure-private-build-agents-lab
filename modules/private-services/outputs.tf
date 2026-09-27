output "container_id" {
  description = "Container id."
  value       = azurerm_storage_container.state.id
}

output "container_name" {
  description = "Container name."
  value       = azurerm_storage_container.state.name
}

output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.state.name
}

output "key_vault_id" {
  description = "Key vault id."
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Key vault name."
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "Key vault uri."
  value       = azurerm_key_vault.this.vault_uri
}

output "blob_private_ip" {
  description = "Blob private ip."
  value       = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}

output "vault_private_ip" {
  description = "Vault private ip."
  value       = azurerm_private_endpoint.vault.private_service_connection[0].private_ip_address
}

output "storage_account_id" {
  description = "State account ARM ID for the foundation-owned delete lock."
  value       = azurerm_storage_account.state.id
}
