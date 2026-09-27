output "id" {
  description = "Pool identity ARM resource ID; no workload/data grants by default."
  value       = azurerm_user_assigned_identity.agent.id
}
output "client_id" {
  description = "Pool identity client ID."
  value       = azurerm_user_assigned_identity.agent.client_id
}
output "principal_id" {
  description = "Pool identity object ID."
  value       = azurerm_user_assigned_identity.agent.principal_id
}
