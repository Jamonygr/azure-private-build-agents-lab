variable "lab_id" {
  type        = string
  description = "Lab ownership identifier."
}

variable "location" {
  type        = string
  description = "Explicit Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Existing foundation resource group."
}

variable "tags" {
  type        = map(string)
  description = "Ownership and descriptive tags."
}

variable "vnet_id" {
  type        = string
  description = "VNet whose DNS settings are managed here."
}

variable "firewall_subnet_id" {
  type        = string
  description = "AzureFirewallSubnet ID."
}

variable "agent_subnet_id" {
  type        = string
  description = "Subnet to associate with the outbound route table."
}

variable "organization_url" {
  type        = string
  description = "DevOps organization URL for narrowly scoped artifact endpoints."
}

variable "workspace_resource_id" {
  type        = string
  description = "Diagnostic workspace ARM ID."
}
