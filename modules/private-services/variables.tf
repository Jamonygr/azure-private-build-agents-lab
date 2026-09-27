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

variable "suffix" {
  type        = string
  description = "Deterministic globally unique name suffix."
}

variable "tenant_id" {
  type        = string
  description = "Key Vault tenant ID."
}

variable "vnet_id" {
  type        = string
  description = "VNet linked to private DNS."
}

variable "endpoint_subnet_id" {
  type        = string
  description = "Dedicated private endpoint subnet."
}

variable "workspace_resource_id" {
  type        = string
  description = "Diagnostic workspace ARM ID."
}
