resource "azurerm_resource_group" "foundation" {
  name     = "rg-${var.lab_id}-foundation"
  location = var.location
  tags     = local.tags
}
resource "azurerm_resource_group" "workload" {
  name     = "rg-${var.lab_id}-workload"
  location = var.location
  tags     = local.tags
}
module "networking" {
  source              = "./modules/networking"
  lab_id              = var.lab_id
  location            = var.location
  resource_group_name = azurerm_resource_group.foundation.name
  address_space       = var.vnet_address_space
  tags                = local.tags
}
module "monitoring" {
  source              = "./modules/monitoring"
  lab_id              = var.lab_id
  location            = var.location
  resource_group_name = azurerm_resource_group.foundation.name
  tags                = local.tags
}
module "egress" {
  source                = "./modules/egress"
  lab_id                = var.lab_id
  location              = var.location
  resource_group_name   = azurerm_resource_group.foundation.name
  vnet_id               = module.networking.vnet_id
  firewall_subnet_id    = module.networking.firewall_subnet_id
  agent_subnet_id       = module.networking.agent_subnet_id
  organization_url      = var.azure_devops_organization_url
  workspace_resource_id = module.monitoring.workspace_resource_id
  tags                  = local.tags
}
module "private_services" {
  source                = "./modules/private-services"
  lab_id                = var.lab_id
  suffix                = local.suffix
  tenant_id             = var.tenant_id
  location              = var.location
  resource_group_name   = azurerm_resource_group.foundation.name
  vnet_id               = module.networking.vnet_id
  endpoint_subnet_id    = module.networking.endpoint_subnet_id
  workspace_resource_id = module.monitoring.workspace_resource_id
  tags                  = local.tags
}
module "identity" {
  source                             = "./modules/identity"
  lab_id                             = var.lab_id
  location                           = var.location
  resource_group_name                = azurerm_resource_group.foundation.name
  workload_resource_group_id         = azurerm_resource_group.workload.id
  state_container_id                 = module.private_services.container_id
  key_vault_id                       = module.private_services.key_vault_id
  vnet_id                            = module.networking.vnet_id
  devops_infrastructure_principal_id = var.devops_infrastructure_principal_id
  operator_principal_id              = var.operator_principal_id
  enable_secret_seed                 = var.enable_secret_seed
  tags                               = local.tags
}
module "pool" {
  source               = "./modules/pool"
  lab_id               = var.lab_id
  location             = var.location
  resource_group_name  = azurerm_resource_group.foundation.name
  agent_subnet_id      = module.networking.agent_subnet_id
  organization_url     = var.azure_devops_organization_url
  project_name         = var.azure_devops_project_name
  administrator_emails = var.pool_administrator_emails
  identity_id          = module.identity.id
  tags                 = local.tags
  depends_on           = [module.egress, module.private_services, module.identity]
}

resource "azurerm_management_lock" "state" {
  name       = "state-account-delete-protection"
  scope      = module.private_services.storage_account_id
  lock_level = "CanNotDelete"
  notes      = "Destroy workloads first; independent operator teardown removes this lock before dependent resources."
  depends_on = [module.identity, module.pool]
}
