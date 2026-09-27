# Workload Terraform reference

Generated from Terraform source. Do not edit this reference manually.

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | = 1.16.4 |
| azurerm | = 5.6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | 5.6.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_network_security_group.sample](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/network_security_group) | resource |
| [azurerm_subnet.sample](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.sample](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.sample](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| lab\_id | Lab ownership identifier from the foundation. | `string` | n/a | yes |
| location | Explicit target Azure region. | `string` | n/a | yes |
| resource\_group\_name | Existing workload resource group owned by foundation. | `string` | n/a | yes |
| subscription\_id | Explicit target subscription. | `string` | n/a | yes |
| tenant\_id | Explicit target tenant. | `string` | n/a | yes |
| vnet\_address\_space | Isolated sample IPv4 /16, never peered to the agent network. | `string` | `"10.70.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| nsg\_id | Sample NSG resource ID. |
| subnet\_id | Sample subnet resource ID. |
| vnet\_id | Sample VNet resource ID. |
