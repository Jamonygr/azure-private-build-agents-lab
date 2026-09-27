# private-services module

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
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/key_vault) | resource |
| [azurerm_monitor_diagnostic_setting.blob](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_monitor_diagnostic_setting.vault](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_private_dns_zone.blob](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone.vault](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.blob](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_dns_zone_virtual_network_link.vault](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.blob](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/private_endpoint) | resource |
| [azurerm_private_endpoint.vault](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/private_endpoint) | resource |
| [azurerm_storage_account.state](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/storage_account) | resource |
| [azurerm_storage_container.state](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/storage_container) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| endpoint\_subnet\_id | Dedicated private endpoint subnet. | `string` | n/a | yes |
| lab\_id | Lab ownership identifier. | `string` | n/a | yes |
| location | Explicit Azure region. | `string` | n/a | yes |
| resource\_group\_name | Existing foundation resource group. | `string` | n/a | yes |
| suffix | Deterministic globally unique name suffix. | `string` | n/a | yes |
| tags | Ownership and descriptive tags. | `map(string)` | n/a | yes |
| tenant\_id | Key Vault tenant ID. | `string` | n/a | yes |
| vnet\_id | VNet linked to private DNS. | `string` | n/a | yes |
| workspace\_resource\_id | Diagnostic workspace ARM ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| blob\_private\_ip | Blob private ip. |
| container\_id | Container id. |
| container\_name | Container name. |
| key\_vault\_id | Key vault id. |
| key\_vault\_name | Key vault name. |
| key\_vault\_uri | Key vault uri. |
| storage\_account\_id | State account ARM ID for the foundation-owned delete lock. |
| storage\_account\_name | Storage account name. |
| vault\_private\_ip | Vault private ip. |
