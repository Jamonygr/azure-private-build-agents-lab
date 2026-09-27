output "workspace_resource_id" {
  description = "Log Analytics ARM ID for diagnostics."
  value       = azurerm_log_analytics_workspace.this.id
}
output "workspace_id" {
  description = "Workspace GUID for log queries."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}
