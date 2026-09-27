output "vnet_id" {
  description = "Foundation VNet ARM resource ID."
  value       = azurerm_virtual_network.this.id
}
output "firewall_subnet_id" {
  description = "Dedicated Firewall subnet ID."
  value       = azurerm_subnet.firewall.id
}
output "agent_subnet_id" {
  description = "Exclusively delegated MDP agent subnet ID."
  value       = azurerm_subnet.agents.id
}
output "endpoint_subnet_id" {
  description = "Private endpoint subnet ID."
  value       = azurerm_subnet.endpoints.id
}
