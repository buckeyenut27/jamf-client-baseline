# MIGRATION TODO (added 2026-06-11, deadline ~2026-10-22): the released
# jamfplatform provider deprecates the flat `software_update` /
# `passcode_policy` attributes in favor of `component_blocks`. Current syntax
# WORKS (warning only) but may be removed on/after 2026-10-22. Migrate these
# three blueprints to component_blocks once the provider documents the new
# schema — check the resource docs when the deprecation warning appears.
#
# macOS Software Update enforcement via Jamf Blueprints (Jamf Platform API).
#
# MSP standard ("set and forget" pattern):
#   1. Minor updates  — "Ignore major versions" CHECKED, enforced 14 days
#      after release, installs at the configured local device time.
#   2. Major upgrades — "Ignore major versions" UNCHECKED, enforced 30 days
#      after release (30 is the API maximum).
#
# Both target the tenant's built-in all-computers device group, looked up by
# name through the Platform API (device groups sync from Jamf Pro).
#
# Requires Jamf Platform API credentials (Jamf Account), separate from the
# Jamf Pro API client — see README Step 3.

locals {
  platform_in_use = var.enable_software_update_blueprints || var.enable_passcode_blueprint || var.enable_cis_benchmark
}

data "jamfplatform_device_groups" "swu_target" {
  count = local.platform_in_use ? 1 : 0

  filter = [
    {
      selector = "name"
      argument = var.software_update_device_group_name
    },
    {
      join_with = "and"
      selector  = "deviceType"
      argument  = "COMPUTER"
    }
  ]
}

locals {
  swu_group_ids = local.platform_in_use ? [
    for g in data.jamfplatform_device_groups.swu_target[0].device_groups : g.id
  ] : []
}

resource "jamfplatform_blueprints_blueprint" "macos_minor_updates" {
  count = var.enable_software_update_blueprints ? 1 : 0

  name        = "macOS Software Updates - Minor (${var.software_update_minor_days} days)"
  description = "Managed by Terraform. Enforces the latest minor macOS update ${var.software_update_minor_days} days after release at ${var.software_update_install_time} local time. Major versions ignored."
  deployed    = true

  device_groups = [local.swu_group_ids[0]]

  software_update = {
    ignore_major_versions = true
    enforce_after_days    = var.software_update_minor_days
    deployment_time       = var.software_update_install_time
  }

  lifecycle {
    precondition {
      condition     = length(local.swu_group_ids) > 0
      error_message = "No Platform device group named '${var.software_update_device_group_name}' was found. Check software_update_device_group_name in terraform.tfvars, or confirm the tenant's device groups have synced to the Jamf Platform."
    }
  }
}

# Passcode policy via DDM (Blueprints passcode_policy component).
# CAUTION: enforcing a minimum length forces non-compliant users to change
# their password. Default minimum is 8 to limit disruption — raise per client
# via passcode_min_length once users are warned.
resource "jamfplatform_blueprints_blueprint" "passcode_policy" {
  count = var.enable_passcode_blueprint ? 1 : 0

  name        = "Passcode Policy - Baseline"
  description = "Managed by Terraform. Minimum length ${var.passcode_min_length}, max 10 failed attempts, 15 min max inactivity."
  deployed    = true

  device_groups = [local.swu_group_ids[0]]

  passcode_policy = {
    require_passcode              = true
    minimum_length                = var.passcode_min_length
    maximum_failed_attempts       = 10
    maximum_inactivity_in_minutes = 15
  }

  lifecycle {
    precondition {
      condition     = length(local.swu_group_ids) > 0
      error_message = "No Platform device group named '${var.software_update_device_group_name}' was found. Check software_update_device_group_name in terraform.tfvars."
    }
  }
}

resource "jamfplatform_blueprints_blueprint" "macos_major_upgrades" {
  count = var.enable_software_update_blueprints ? 1 : 0

  name        = "macOS Software Updates - Major (${var.software_update_major_days} days)"
  description = "Managed by Terraform. Enforces the latest macOS version (including major upgrades) ${var.software_update_major_days} days after release at ${var.software_update_install_time} local time."
  deployed    = true

  device_groups = [local.swu_group_ids[0]]

  software_update = {
    ignore_major_versions = false
    enforce_after_days    = var.software_update_major_days
    deployment_time       = var.software_update_install_time
  }

  lifecycle {
    precondition {
      condition     = length(local.swu_group_ids) > 0
      error_message = "No Platform device group named '${var.software_update_device_group_name}' was found. Check software_update_device_group_name in terraform.tfvars, or confirm the tenant's device groups have synced to the Jamf Platform."
    }
  }
}
