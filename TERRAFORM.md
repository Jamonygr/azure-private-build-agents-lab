# Foundation Terraform reference

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

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| egress | ./modules/egress | n/a |
| identity | ./modules/identity | n/a |
| monitoring | ./modules/monitoring | n/a |
| networking | ./modules/networking | n/a |
| pool | ./modules/pool | n/a |
| private\_services | ./modules/private-services | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_management_lock.state](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/management_lock) | resource |
| [azurerm_resource_group.foundation](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/resource_group) | resource |
| [azurerm_resource_group.workload](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/resource_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| azure\_devops\_organization\_url | Existing Azure DevOps Services organization URL. | `string` | n/a | yes |
| azure\_devops\_project\_name | Existing project to which this pool is restricted. | `string` | n/a | yes |
| devops\_infrastructure\_principal\_id | Object ID of the Microsoft DevOpsInfrastructure service principal in this tenant. | `string` | n/a | yes |
| enable\_secret\_seed | Temporary Secrets Officer grant for one operator seed operation; remove before ordinary exercises. | `bool` | `false` | no |
| lab\_id | Unique lab ownership identifier; lowercase letter followed by 2-11 letters or digits. | `string` | `"pbalab"` | no |
| location | Explicit supported region; preflight checks MDP availability and quota. | `string` | `"westeurope"` | no |
| operator\_principal\_id | Object ID of the operator who runs workload Terraform and private validation with Azure CLI. | `string` | n/a | yes |
| pool\_administrator\_emails | Explicit existing DevOps users allowed to administer the pool. | `list(string)` | n/a | yes |
| subscription\_id | Target Azure subscription GUID. No implicit account switching. | `string` | n/a | yes |
| tags | Additional tags; mandatory ownership tags cannot be overridden. | `map(string)` | `{}` | no |
| tenant\_id | Microsoft Entra tenant GUID containing the Azure subscription and DevOps organization. | `string` | n/a | yes |
| vnet\_address\_space | Foundation IPv4 /16; cannot use the MDP internal range 172.17.0.0/16. | `string` | `"10.60.0.0/16"` | no |
| workload\_vnet\_address\_space | Isolated sample workload IPv4 /16; must not overlap the foundation. | `string` | `"10.70.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| lab\_configuration | Non-secret configuration exported for operator scripts and private-connected validation hosts. |
