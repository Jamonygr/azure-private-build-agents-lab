package main
import rego.v1

# Evaluate actual Terraform plan JSON, including module resource changes.
resources contains r if {
  some r in input.resource_changes
  r.change.after != null
}

deny contains sprintf("%s: state storage public access must be Disabled", [r.address]) if {
  some r in resources
  r.type == "azurerm_storage_account"
  object.get(r.change.after, "public_network_access", null) != "Disabled"
}
deny contains sprintf("%s: shared-key access must be disabled", [r.address]) if {
  some r in resources
  r.type == "azurerm_storage_account"
  object.get(r.change.after, "shared_access_key_enabled", null) != false
}
deny contains sprintf("%s: anonymous Blob access must be disabled", [r.address]) if {
  some r in resources
  r.type == "azurerm_storage_account"
  object.get(r.change.after, "allow_nested_items_to_be_public", null) != false
}
deny contains sprintf("%s: vault public access must be disabled", [r.address]) if {
  some r in resources
  r.type == "azurerm_key_vault"
  object.get(r.change.after, "public_network_access_enabled", null) != false
}
deny contains sprintf("%s: vault must use RBAC", [r.address]) if {
  some r in resources
  r.type == "azurerm_key_vault"
  object.get(r.change.after, "rbac_authorization_enabled", null) != true
}
deny contains sprintf("%s: role assignments cannot target a subscription", [r.address]) if {
  some r in resources
  r.type == "azurerm_role_assignment"
  is_string(r.change.after.scope)
  not contains(lower(r.change.after.scope), "/resourcegroups/")
}
deny contains sprintf("%s: temporary secret write requires explicit enable_secret_seed", [r.address]) if {
  some r in resources
  r.type == "azurerm_role_assignment"
  r.change.after.role_definition_name == "Key Vault Secrets Officer"
  object.get(object.get(object.get(input, "variables", {}), "enable_secret_seed", {}), "value", false) != true
}
deny contains sprintf("%s: default outbound route must use the Firewall", [r.address]) if {
  some r in resources
  r.type == "azurerm_route"
  r.change.after.address_prefix == "0.0.0.0/0"
  r.change.after.next_hop_type != "VirtualAppliance"
}
deny contains sprintf("%s: pool concurrency must remain one", [r.address]) if {
  some r in resources
  r.type == "azurerm_managed_devops_pool"
  object.get(r.change.after, "maximum_concurrency", null) != 1
}

warn contains sprintf("%s: RBAC scope is unresolved; scoped permissions have not been verified", [r.address]) if {
  some r in resources
  r.type == "azurerm_role_assignment"
  not is_string(object.get(r.change.after, "scope", null))
}
