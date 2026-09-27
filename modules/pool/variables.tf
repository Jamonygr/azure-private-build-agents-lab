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

variable "agent_subnet_id" {
  type        = string
  description = "Exclusively delegated subnet in the same region."
}

variable "organization_url" {
  type        = string
  description = "Existing Azure DevOps organization URL."
}

variable "project_name" {
  type        = string
  description = "Only project to which this pool is available."
}

variable "administrator_emails" {
  type        = list(string)
  description = "Explicit existing pool administrators."
}

variable "identity_id" {
  type        = string
  description = "Pool user-assigned managed identity ARM ID."
}
