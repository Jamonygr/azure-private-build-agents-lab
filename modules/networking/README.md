# networking module

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
| [azurerm_network_security_group.agents](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/network_security_group) | resource |
| [azurerm_subnet.agents](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/subnet) | resource |
| [azurerm_subnet.endpoints](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/subnet) | resource |
| [azurerm_subnet.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.agents](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| address\_space | Foundation IPv4 /16. | `string` | n/a | yes |
| lab\_id | Lab ownership identifier. | `string` | n/a | yes |
| location | Explicit Azure region. | `string` | n/a | yes |
| resource\_group\_name | Existing foundation resource group. | `string` | n/a | yes |
| tags | Ownership and descriptive tags. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| agent\_subnet\_id | Exclusively delegated MDP agent subnet ID. |
| endpoint\_subnet\_id | Private endpoint subnet ID. |
| firewall\_subnet\_id | Dedicated Firewall subnet ID. |
| vnet\_id | Foundation VNet ARM resource ID. |
