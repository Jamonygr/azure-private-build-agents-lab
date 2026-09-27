output "vnet_id" {
  description = "Sample VNet resource ID."
  value       = azurerm_virtual_network.sample.id
}
output "subnet_id" {
  description = "Sample subnet resource ID."
  value       = azurerm_subnet.sample.id
}
output "nsg_id" {
  description = "Sample NSG resource ID."
  value       = azurerm_network_security_group.sample.id
}
