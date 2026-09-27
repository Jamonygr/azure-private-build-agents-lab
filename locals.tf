locals {
  suffix = substr(sha256("${var.subscription_id}/${var.lab_id}"), 0, 6)
  tags = merge(var.tags, {
    lab_id      = var.lab_id
    environment = "lab"
    managed_by  = "terraform"
    project     = "azure-private-build-agents-lab"
  })
}
