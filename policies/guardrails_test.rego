package main
import rego.v1

change(kind, after) := {"address": sprintf("%s.example", [kind]), "type": kind, "change": {"after": after}}
plan(kind, after) := {"resource_changes": [change(kind, after)]}

storage := {"public_network_access": "Disabled", "shared_access_key_enabled": false, "allow_nested_items_to_be_public": false}
vault := {"public_network_access_enabled": false, "rbac_authorization_enabled": true}

test_private_storage_allowed if {
  count(deny) == 0 with input as plan("azurerm_storage_account", storage)
}
test_public_storage_denied if {
  count(deny) == 1 with input as plan("azurerm_storage_account", object.union(storage, {"public_network_access": "Enabled"}))
}
test_account_key_denied if {
  count(deny) == 1 with input as plan("azurerm_storage_account", object.union(storage, {"shared_access_key_enabled": true}))
}
test_public_blob_denied if {
  count(deny) == 1 with input as plan("azurerm_storage_account", object.union(storage, {"allow_nested_items_to_be_public": true}))
}
test_private_rbac_vault_allowed if {
  count(deny) == 0 with input as plan("azurerm_key_vault", vault)
}
test_public_vault_denied if {
  count(deny) == 1 with input as plan("azurerm_key_vault", object.union(vault, {"public_network_access_enabled": true}))
}
test_access_policy_vault_denied if {
  count(deny) == 1 with input as plan("azurerm_key_vault", object.union(vault, {"rbac_authorization_enabled": false}))
}
test_subscription_grant_denied if {
  count(deny) == 1 with input as plan("azurerm_role_assignment", {"scope": "/subscriptions/11111111-1111-1111-1111-111111111111", "role_definition_name": "Contributor"})
}
test_resource_group_grant_allowed if {
  count(deny) == 0 with input as plan("azurerm_role_assignment", {"scope": "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-testlab-workload", "role_definition_name": "Contributor"})
}
test_unrequested_secret_writer_denied if {
  count(deny) == 1 with input as plan("azurerm_role_assignment", {"scope": "/subscriptions/s/resourceGroups/r/providers/Microsoft.KeyVault/vaults/v", "role_definition_name": "Key Vault Secrets Officer"})
}
test_explicit_temporary_seed_allowed if {
  x := object.union(plan("azurerm_role_assignment", {"scope": "/subscriptions/s/resourceGroups/r/providers/Microsoft.KeyVault/vaults/v", "role_definition_name": "Key Vault Secrets Officer"}), {"variables": {"enable_secret_seed": {"value": true}}})
  count(deny) == 0 with input as x
}
test_direct_internet_route_denied if {
  count(deny) == 1 with input as plan("azurerm_route", {"address_prefix": "0.0.0.0/0", "next_hop_type": "Internet"})
}
test_firewall_route_allowed if {
  count(deny) == 0 with input as plan("azurerm_route", {"address_prefix": "0.0.0.0/0", "next_hop_type": "VirtualAppliance"})
}
test_excess_pool_capacity_denied if {
  count(deny) == 1 with input as plan("azurerm_managed_devops_pool", {"maximum_concurrency": 2})
}
test_delete_only_plan_allowed if {
  count(deny) == 0 with input as {"resource_changes": [{"address": "azurerm_storage_account.state", "type": "azurerm_storage_account", "change": {"after": null}}]}
}

test_unknown_storage_controls_are_not_a_pass if {
  count(deny) == 3 with input as plan("azurerm_storage_account", {})
}
test_unknown_vault_controls_are_not_a_pass if {
  count(deny) == 2 with input as plan("azurerm_key_vault", {})
}
test_unknown_capacity_is_not_a_pass if {
  count(deny) == 1 with input as plan("azurerm_managed_devops_pool", {})
}
test_unresolved_rbac_scope_requires_review if {
  count(warn) == 1 with input as plan("azurerm_role_assignment", {"role_definition_name": "Contributor"})
}
