# Variables for the optional client-platform module.
# Values flow from the client folder's terraform.tfvars via platform.tf.

variable "enable_software_update_blueprints" {
  description = "Create the two macOS software update Blueprints (minor: ignore major versions, 14 days; major: 30 days)."
  type        = bool
  default     = true
}

variable "software_update_minor_days" {
  description = "Days after release to enforce minor macOS updates (major versions ignored)."
  type        = number
  default     = 14

  validation {
    condition     = var.software_update_minor_days >= 1 && var.software_update_minor_days <= 30
    error_message = "software_update_minor_days must be 1-30 (API maximum is 30)."
  }
}

variable "software_update_major_days" {
  description = "Days after release to enforce major macOS upgrades."
  type        = number
  default     = 30

  validation {
    condition     = var.software_update_major_days >= 1 && var.software_update_major_days <= 30
    error_message = "software_update_major_days must be 1-30 (API maximum is 30)."
  }
}

variable "software_update_install_time" {
  description = "Local device time (HH:mm, 24-hour) when enforced updates install."
  type        = string
  default     = "23:45"
}

variable "software_update_device_group_name" {
  description = "Name of the Platform device group the blueprints target. Defaults to Jamf Pro's built-in all-computers smart group."
  type        = string
  default     = "All Managed Clients"
}

variable "enable_passcode_blueprint" {
  description = "Deploy the passcode policy Blueprint. CAUTION: non-compliant users are forced to change passwords."
  type        = bool
  default     = true
}

variable "passcode_min_length" {
  description = "Minimum password length enforced by the passcode Blueprint."
  type        = number
  default     = 8

  validation {
    condition     = var.passcode_min_length >= 0 && var.passcode_min_length <= 16
    error_message = "passcode_min_length must be 0-16."
  }
}

variable "enable_cis_benchmark" {
  description = "CIS Level 1 benchmark, all controls, MONITOR/report-only (never enforced at build — MSP policy)."
  type        = bool
  default     = true
}
