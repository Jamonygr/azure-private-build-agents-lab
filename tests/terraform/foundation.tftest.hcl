mock_provider "azurerm" {}
variables {
  lab_id              = "testlab"
  location            = "westeurope"
  resource_group_name = "rg-testlab-foundation"
  tags                = { lab_id = "testlab" }
}
run "foundation_contract" {
  command = plan
  variables {
    subscription_id                    = "11111111-1111-1111-1111-111111111111"
    tenant_id                          = "22222222-2222-2222-2222-222222222222"
    operator_principal_id              = "33333333-3333-3333-3333-333333333333"
    devops_infrastructure_principal_id = "44444444-4444-4444-4444-444444444444"
    azure_devops_organization_url      = "https://dev.azure.com/testorg"
    azure_devops_project_name          = "Learning"
    pool_administrator_emails          = ["operator@example.com"]
  }
  assert {
    condition     = output.lab_configuration.state_key == "workload/testlab.tfstate" && !output.lab_configuration.bootstrap_secret_write_enabled
    error_message = "Normal foundation must use an isolated state key and no seed grant."
  }
  assert {
    condition     = azurerm_resource_group.workload.name == "rg-testlab-workload" && azurerm_resource_group.workload.tags.lab_id == "testlab"
    error_message = "Workload ownership must be explicit."
  }
}
run "network_boundary" {
  command = plan
  module { source = "./modules/networking" }
  variables { address_space = "10.60.0.0/16" }
  assert {
    condition     = azurerm_subnet.agents.delegation[0].service_delegation[0].name == "Microsoft.DevOpsInfrastructure/pools" && !azurerm_subnet.agents.default_outbound_access_enabled
    error_message = "Agents need exclusive MDP delegation and explicit outbound routing."
  }
  assert {
    condition     = azurerm_subnet.firewall.address_prefixes == tolist(["10.60.0.0/26"]) && azurerm_subnet.endpoints.address_prefixes == tolist(["10.60.2.0/27"])
    error_message = "Firewall and private endpoints must use separate subnets."
  }
}
run "private_service_controls" {
  command = plan
  module { source = "./modules/private-services" }
  variables {
    suffix                = "123456"
    tenant_id             = "22222222-2222-2222-2222-222222222222"
    vnet_id               = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Network/virtualNetworks/vnet-testlab"
    endpoint_subnet_id    = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Network/virtualNetworks/vnet-testlab/subnets/snet-private-endpoints"
    workspace_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.OperationalInsights/workspaces/law-testlab"
  }
  assert {
    condition     = azurerm_storage_account.state.public_network_access == "Disabled" && !azurerm_storage_account.state.shared_access_key_enabled && !azurerm_storage_account.state.allow_nested_items_to_be_public
    error_message = "State storage must never permit public networking, account-key authorization or public blobs."
  }
  assert {
    condition     = !azurerm_key_vault.this.public_network_access_enabled && azurerm_key_vault.this.rbac_authorization_enabled && azurerm_key_vault.this.purge_protection_enabled
    error_message = "Key Vault must have private networking, RBAC and purge protection."
  }
  assert {
    condition     = azurerm_storage_container.state.container_access_type == "private" && azurerm_storage_account.state.blob_properties[0].versioning_enabled
    error_message = "State blobs must be private and versioned."
  }
}
run "egress_controls" {
  command = plan
  module { source = "./modules/egress" }
  variables {
    vnet_id               = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Network/virtualNetworks/vnet-testlab"
    firewall_subnet_id    = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Network/virtualNetworks/vnet-testlab/subnets/AzureFirewallSubnet"
    agent_subnet_id       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Network/virtualNetworks/vnet-testlab/subnets/snet-agents"
    organization_url      = "https://dev.azure.com/testorg"
    workspace_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.OperationalInsights/workspaces/law-testlab"
  }
  assert {
    condition     = azurerm_firewall.this.sku_tier == "Standard" && azurerm_firewall_policy.this.dns[0].proxy_enabled
    error_message = "Standard Firewall and DNS proxy are baseline requirements."
  }
  assert {
    condition     = azurerm_route.default.address_prefix == "0.0.0.0/0" && azurerm_route.default.next_hop_type == "VirtualAppliance"
    error_message = "Agent outbound traffic must route to the Firewall."
  }
  assert {
    condition     = contains(output.allowed_https_fqdns, "dev.azure.com") && !contains(output.allowed_https_fqdns, "*") && !contains(output.allowed_https_fqdns, "*.com")
    error_message = "Required destinations must be explicit; blanket internet allowlists are forbidden."
  }
}
run "operator_least_privilege" {
  command = plan
  module { source = "./modules/identity" }
  variables {
    workload_resource_group_id         = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-workload"
    state_container_id                 = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Storage/storageAccounts/sttestlab123456/blobServices/default/containers/tfstate"
    key_vault_id                       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.KeyVault/vaults/kv-testlab-123456"
    vnet_id                            = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Network/virtualNetworks/vnet-testlab"
    operator_principal_id              = "33333333-3333-3333-3333-333333333333"
    devops_infrastructure_principal_id = "44444444-4444-4444-4444-444444444444"
    enable_secret_seed                 = false
  }
  assert {
    condition     = length(azurerm_role_assignment.operator_secret_seed) == 0 && azurerm_role_assignment.operator_state.scope == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Storage/storageAccounts/sttestlab123456/blobServices/default/containers/tfstate"
    error_message = "Ordinary operators must have no secret-write assignment and state scope must be the container."
  }
  assert {
    condition     = azurerm_role_assignment.operator_workload.scope == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-workload"
    error_message = "Sample deployment permissions must be resource-group scoped."
  }
}
run "temporary_seed_grant" {
  command = plan
  module { source = "./modules/identity" }
  variables {
    workload_resource_group_id         = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-workload"
    state_container_id                 = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Storage/storageAccounts/sttestlab123456/blobServices/default/containers/tfstate"
    key_vault_id                       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.KeyVault/vaults/kv-testlab-123456"
    vnet_id                            = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Network/virtualNetworks/vnet-testlab"
    operator_principal_id              = "33333333-3333-3333-3333-333333333333"
    devops_infrastructure_principal_id = "44444444-4444-4444-4444-444444444444"
    enable_secret_seed                 = true
  }
  assert {
    condition     = length(azurerm_role_assignment.operator_secret_seed) == 1 && azurerm_role_assignment.operator_secret_seed[0].principal_id == "33333333-3333-3333-3333-333333333333" && azurerm_role_assignment.operator_secret_seed[0].role_definition_name == "Key Vault Secrets Officer"
    error_message = "Seed permission must grant only the explicit operator the temporary secret role."
  }
}
run "stateless_windows_pool" {
  command = plan
  module { source = "./modules/pool" }
  variables {
    agent_subnet_id      = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.Network/virtualNetworks/vnet-testlab/subnets/snet-agents"
    organization_url     = "https://dev.azure.com/testorg"
    project_name         = "Learning"
    administrator_emails = ["operator@example.com"]
    identity_id          = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-foundation/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-testlab"
  }
  assert {
    condition     = azurerm_managed_devops_pool.this.maximum_concurrency == 1 && length(azurerm_managed_devops_pool.this.stateless_agent) == 1
    error_message = "Pool must use one disposable agent and no stateful retention."
  }
  assert {
    condition     = azurerm_managed_devops_pool.this.virtual_machine_scale_set_fabric[0].sku_name == "Standard_D2ads_v5" && azurerm_managed_devops_pool.this.virtual_machine_scale_set_fabric[0].image[0].well_known_image_name == "windows-2025-g2"
    error_message = "Use the verified Windows Gen2 image and compatible v5 SKU."
  }
}
