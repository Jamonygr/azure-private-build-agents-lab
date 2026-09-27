resource "azurerm_dev_center" "this" {
  name                = "dc-${var.lab_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_dev_center_project" "this" {
  name                = "dcp-${var.lab_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dev_center_id       = azurerm_dev_center.this.id
  tags                = var.tags
}
resource "azurerm_managed_devops_pool" "this" {
  name                  = "mdp-${var.lab_id}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  dev_center_project_id = azurerm_dev_center_project.this.id
  maximum_concurrency   = 1
  azure_devops_organization {
    organization {
      url         = var.organization_url
      projects    = [var.project_name]
      parallelism = 1
    }
    permission {
      kind = "SpecificAccounts"
      administrator_account {
        users = var.administrator_emails
      }
    }
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }
  stateless_agent {}
  virtual_machine_scale_set_fabric {
    sku_name                     = "Standard_D2ads_v5"
    subnet_id                    = var.agent_subnet_id
    os_disk_storage_account_type = "StandardSSD"
    image {
      well_known_image_name = "windows-2025-g2"
      aliases               = ["lab-windows"]
    }
    security {
      interactive_logon_enabled = false
    }
  }
  tags = var.tags
}
