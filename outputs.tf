output "lab_configuration" {
  description = "Non-secret configuration exported for operator scripts and private-connected validation hosts."
  value = {
    lab_id                         = var.lab_id
    subscription_id                = var.subscription_id
    tenant_id                      = var.tenant_id
    location                       = var.location
    foundation_resource_group_name = azurerm_resource_group.foundation.name
    workload_resource_group_name   = azurerm_resource_group.workload.name
    pool_name                      = module.pool.name
    azure_devops_organization_url  = var.azure_devops_organization_url
    azure_devops_project_name      = var.azure_devops_project_name
    agent_identity_client_id       = module.identity.client_id
    agent_identity_principal_id    = module.identity.principal_id
    state_storage_account_name     = module.private_services.storage_account_name
    state_container_name           = module.private_services.container_name
    state_key                      = "workload/${var.lab_id}.tfstate"
    key_vault_name                 = module.private_services.key_vault_name
    key_vault_uri                  = module.private_services.key_vault_uri
    blob_private_ip                = module.private_services.blob_private_ip
    vault_private_ip               = module.private_services.vault_private_ip
    firewall_private_ip            = module.egress.firewall_private_ip
    firewall_resource_id           = module.egress.firewall_id
    log_analytics_workspace_id     = module.monitoring.workspace_id
    bootstrap_secret_write_enabled = var.enable_secret_seed
    workload_vnet_cidr             = var.workload_vnet_address_space
    operator_principal_id          = var.operator_principal_id
  }
}
