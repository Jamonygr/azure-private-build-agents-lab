resource "azurerm_user_assigned_identity" "agent" {
  name                = "id-${var.lab_id}-agents"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
# This pool identity deliberately has no workload or secret grants in the operator-only lab.
resource "azurerm_role_assignment" "operator_workload" {
  scope                = var.workload_resource_group_id
  role_definition_name = "Contributor"
  principal_id         = var.operator_principal_id
}
resource "azurerm_role_assignment" "operator_state" {
  scope                = var.state_container_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.operator_principal_id
}
resource "azurerm_role_assignment" "operator_secret_read" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.operator_principal_id
}
resource "azurerm_role_assignment" "operator_secret_seed" {
  count                = var.enable_secret_seed ? 1 : 0
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.operator_principal_id
}
resource "azurerm_role_assignment" "mdp_network" {
  scope                            = var.vnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = var.devops_infrastructure_principal_id
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "mdp_reader" {
  scope                            = var.vnet_id
  role_definition_name             = "Reader"
  principal_id                     = var.devops_infrastructure_principal_id
  skip_service_principal_aad_check = true
}
