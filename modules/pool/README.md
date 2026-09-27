# pool module

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
| [azurerm_dev_center.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/dev_center) | resource |
| [azurerm_dev_center_project.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/dev_center_project) | resource |
| [azurerm_managed_devops_pool.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/managed_devops_pool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| administrator\_emails | Explicit existing pool administrators. | `list(string)` | n/a | yes |
| agent\_subnet\_id | Exclusively delegated subnet in the same region. | `string` | n/a | yes |
| identity\_id | Pool user-assigned managed identity ARM ID. | `string` | n/a | yes |
| lab\_id | Lab ownership identifier. | `string` | n/a | yes |
| location | Explicit Azure region. | `string` | n/a | yes |
| organization\_url | Existing Azure DevOps organization URL. | `string` | n/a | yes |
| project\_name | Only project to which this pool is available. | `string` | n/a | yes |
| resource\_group\_name | Existing foundation resource group. | `string` | n/a | yes |
| tags | Ownership and descriptive tags. | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | Managed pool ARM resource ID. |
| name | Managed pool name. |
