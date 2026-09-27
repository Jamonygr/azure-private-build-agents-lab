output "firewall_id" {
  description = "Firewall ARM ID for evidence correlation."
  value       = azurerm_firewall.this.id
}
output "firewall_private_ip" {
  description = "Firewall private IP used by DNS and routing."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}
output "allowed_https_fqdns" {
  description = "Auditable required outbound HTTPS destinations."
  value       = local.allowed_https_fqdns
}
