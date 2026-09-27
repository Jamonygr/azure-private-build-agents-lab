terraform {
  required_version = "= 1.16.4"
  backend "azurerm" {}
}

variable "marker_path" {
  type = string
}

variable "hold_seconds" {
  type    = number
  default = 30
  validation {
    condition     = var.hold_seconds >= 15 && var.hold_seconds <= 60
    error_message = "The lock hold must be between 15 and 60 seconds."
  }
}

# This disposable resource exists only to keep the remote state lease held long
# enough for a second process to attempt a plan. No Azure resources are created.
resource "terraform_data" "hold_lock" {
  provisioner "local-exec" {
    interpreter = ["pwsh", "-NoProfile", "-NonInteractive", "-Command"]
    command     = "[IO.File]::WriteAllText($env:LAB_LOCK_MARKER, 'ready'); Start-Sleep -Seconds ([int]$env:LAB_LOCK_SECONDS)"
    environment = {
      LAB_LOCK_MARKER  = var.marker_path
      LAB_LOCK_SECONDS = tostring(var.hold_seconds)
    }
  }
}
