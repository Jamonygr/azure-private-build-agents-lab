terraform {
  required_version = ">= 1.16.4, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.6.0"
    }
  }
}
