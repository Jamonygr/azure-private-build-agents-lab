variable "subscription_id" {
  description = "Target Azure subscription GUID. No implicit account switching."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "Provide a subscription GUID."
  }
}
variable "tenant_id" {
  description = "Microsoft Entra tenant GUID containing the Azure subscription and DevOps organization."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "Provide a tenant GUID."
  }
}
variable "lab_id" {
  description = "Unique lab ownership identifier; lowercase letter followed by 2-11 letters or digits."
  type        = string
  default     = "pbalab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.lab_id))
    error_message = "lab_id must be 3-12 lowercase alphanumeric characters starting with a letter."
  }
}
variable "location" {
  description = "Explicit supported region; preflight checks MDP availability and quota."
  type        = string
  default     = "westeurope"
}
variable "azure_devops_organization_url" {
  description = "Existing Azure DevOps Services organization URL."
  type        = string
  validation {
    condition     = can(regex("^https://dev[.]azure[.]com/[A-Za-z0-9][A-Za-z0-9-]*$", var.azure_devops_organization_url))
    error_message = "Use https://dev.azure.com/organization without a trailing slash."
  }
}
variable "azure_devops_project_name" {
  description = "Existing project to which this pool is restricted."
  type        = string
  validation {
    condition     = length(trimspace(var.azure_devops_project_name)) > 0
    error_message = "An existing project name is required."
  }
}
variable "pool_administrator_emails" {
  description = "Explicit existing DevOps users allowed to administer the pool."
  type        = list(string)
  validation {
    condition     = length(var.pool_administrator_emails) > 0 && alltrue([for email in var.pool_administrator_emails : can(regex("^[^ @]+@[^ @]+$", email))])
    error_message = "Provide at least one administrator email/UPN."
  }
}
variable "devops_infrastructure_principal_id" {
  description = "Object ID of the Microsoft DevOpsInfrastructure service principal in this tenant."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.devops_infrastructure_principal_id))
    error_message = "Provide the discovered service principal object GUID, not its application ID."
  }
}
variable "enable_secret_seed" {
  description = "Temporary Secrets Officer grant for one operator seed operation; remove before ordinary exercises."
  type        = bool
  default     = false
}
variable "operator_principal_id" {
  description = "Object ID of the operator who runs workload Terraform and private validation with Azure CLI."
  type        = string
  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.operator_principal_id))
    error_message = "Provide the operator object GUID."
  }
}
variable "vnet_address_space" {
  description = "Foundation IPv4 /16; cannot use the MDP internal range 172.17.0.0/16."
  type        = string
  default     = "10.60.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vnet_address_space)) && endswith(var.vnet_address_space, "/16") && !startswith(var.vnet_address_space, "172.17.")
    error_message = "Provide an IPv4 /16 outside 172.17.0.0/16."
  }
}
variable "workload_vnet_address_space" {
  description = "Isolated sample workload IPv4 /16; must not overlap the foundation."
  type        = string
  default     = "10.70.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.workload_vnet_address_space)) && endswith(var.workload_vnet_address_space, "/16") && try(cidrhost(var.workload_vnet_address_space, 0) != cidrhost(var.vnet_address_space, 0), false)
    error_message = "Provide a different IPv4 /16 for the workload."
  }
}
variable "tags" {
  description = "Additional tags; mandatory ownership tags cannot be overridden."
  type        = map(string)
  default     = {}
}
