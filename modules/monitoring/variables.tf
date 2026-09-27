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
