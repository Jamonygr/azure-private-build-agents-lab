variable "subscription_id" {
  description = "Explicit target subscription."
  type        = string
}
variable "tenant_id" {
  description = "Explicit target tenant."
  type        = string
}
variable "lab_id" {
  description = "Lab ownership identifier from the foundation."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.lab_id))
    error_message = "Invalid lab identifier."
  }
}
variable "location" {
  description = "Explicit target Azure region."
  type        = string
}
variable "resource_group_name" {
  description = "Existing workload resource group owned by foundation."
  type        = string
  validation {
    condition     = var.resource_group_name == "rg-${var.lab_id}-workload"
    error_message = "Workload resource group must match the lab identifier."
  }
}
variable "vnet_address_space" {
  description = "Isolated sample IPv4 /16, never peered to the agent network."
  type        = string
  default     = "10.70.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vnet_address_space)) && endswith(var.vnet_address_space, "/16")
    error_message = "Use an IPv4 /16."
  }
}
