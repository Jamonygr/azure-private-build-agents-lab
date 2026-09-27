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

variable "workload_resource_group_id" {
  type        = string
  description = "Scope for operator workload changes."
}

variable "state_container_id" {
  type        = string
  description = "Scope for operator Blob data access."
}

variable "key_vault_id" {
  type        = string
  description = "Scope for secret reading and optional temporary seed writes."
}

variable "vnet_id" {
  type        = string
  description = "Scope for the Microsoft MDP service principal."
}

variable "devops_infrastructure_principal_id" {
  type        = string
  description = "Microsoft service principal object ID."
}

variable "operator_principal_id" {
  type        = string
  description = "Operator object ID for Azure CLI authentication."
}

variable "enable_secret_seed" {
  type        = bool
  description = "Explicit temporary operator Secrets Officer assignment."
}
