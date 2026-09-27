provider "azurerm" {
  subscription_id                 = var.subscription_id
  tenant_id                       = var.tenant_id
  resource_provider_registrations = "none"
  features {}
}
terraform {
  backend "azurerm" {
    use_azuread_auth = true
    use_cli          = true
  }
}
