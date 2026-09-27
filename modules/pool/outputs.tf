output "name" {
  description = "Managed pool name."
  value       = azurerm_managed_devops_pool.this.name
}
output "id" {
  description = "Managed pool ARM resource ID."
  value       = azurerm_managed_devops_pool.this.id
}
