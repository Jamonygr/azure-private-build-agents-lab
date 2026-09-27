mock_provider "azurerm" {}
variables {
  subscription_id     = "11111111-1111-1111-1111-111111111111"
  tenant_id           = "22222222-2222-2222-2222-222222222222"
  lab_id              = "testlab"
  location            = "westeurope"
  resource_group_name = "rg-testlab-workload"
}
run "isolated_sample_network" {
  command = plan
  assert {
    condition     = azurerm_virtual_network.sample.resource_group_name == "rg-testlab-workload" && !azurerm_subnet.sample.default_outbound_access_enabled
    error_message = "Workload must stay in its own RG without implicit outbound access."
  }
  assert {
    condition     = azurerm_network_security_group.sample.tags.lab_id == "testlab"
    error_message = "Sample resources need ownership tags."
  }
}
run "wrong_resource_group_rejected" {
  command = plan
  variables { resource_group_name = "rg-somebody-else" }
  expect_failures = [var.resource_group_name]
}
