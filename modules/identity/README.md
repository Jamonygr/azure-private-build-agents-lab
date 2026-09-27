# identity module

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
| [azurerm_role_assignment.mdp_network](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.mdp_reader](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.operator_secret_read](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.operator_secret_seed](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.operator_state](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.operator_workload](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/role_assignment) | resource |
| [azurerm_user_assigned_identity.agent](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| devops\_infrastructure\_principal\_id | Microsoft service principal object ID. | `string` | n/a | yes |
| enable\_secret\_seed | Explicit temporary operator Secrets Officer assignment. | `bool` | n/a | yes |
| key\_vault\_id | Scope for secret reading and optional temporary seed writes. | `string` | n/a | yes |
| lab\_id | Lab ownership identifier. | `string` | n/a | yes |
| location | Explicit Azure region. | `string` | n/a | yes |
| operator\_principal\_id | Operator object ID for Azure CLI authentication. | `string` | n/a | yes |
| resource\_group\_name | Existing foundation resource group. | `string` | n/a | yes |
| state\_container\_id | Scope for operator Blob data access. | `string` | n/a | yes |
| tags | Ownership and descriptive tags. | `map(string)` | n/a | yes |
| vnet\_id | Scope for the Microsoft MDP service principal. | `string` | n/a | yes |
| workload\_resource\_group\_id | Scope for operator workload changes. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| client\_id | Pool identity client ID. |
| id | Pool identity ARM resource ID; no workload/data grants by default. |
| principal\_id | Pool identity object ID. |
