# egress module

Generated from Terraform source. Do not edit this reference manually.

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.16.4, < 2.0.0 |
| azurerm | = 5.6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | = 5.6.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_firewall.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/firewall) | resource |
| [azurerm_firewall_policy.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/firewall_policy) | resource |
| [azurerm_firewall_policy_rule_collection_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/firewall_policy_rule_collection_group) | resource |
| [azurerm_monitor_diagnostic_setting.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_public_ip.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/public_ip) | resource |
| [azurerm_route.default](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/route) | resource |
| [azurerm_route_table.agents](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/route_table) | resource |
| [azurerm_subnet_route_table_association.agents](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/subnet_route_table_association) | resource |
| [azurerm_virtual_network_dns_servers.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/virtual_network_dns_servers) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| agent\_subnet\_id | Subnet to associate with the outbound route table. | `string` | n/a | yes |
| firewall\_subnet\_id | AzureFirewallSubnet ID. | `string` | n/a | yes |
| lab\_id | Lab ownership identifier. | `string` | n/a | yes |
| location | Explicit Azure region. | `string` | n/a | yes |
| organization\_url | DevOps organization URL for narrowly scoped artifact endpoints. | `string` | n/a | yes |
| resource\_group\_name | Existing foundation resource group. | `string` | n/a | yes |
| tags | Ownership and descriptive tags. | `map(string)` | n/a | yes |
| vnet\_id | VNet whose DNS settings are managed here. | `string` | n/a | yes |
| workspace\_resource\_id | Diagnostic workspace ARM ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| allowed\_https\_fqdns | Auditable required outbound HTTPS destinations. |
| firewall\_id | Firewall ARM ID for evidence correlation. |
| firewall\_private\_ip | Firewall private IP used by DNS and routing. |
