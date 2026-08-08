# Computer Extension Attributes — MSP visibility pack.
#
# Curated from community collections (jamf/Jamf-Nation-Extension-Attributes,
# palantir/jamf-pro-scripts, mm2270/Extension-Attributes, macadmins/sofa) and
# tailored to the MSP stack. Each EA runs at inventory (recon) and becomes
# smart-group-able:
#
#   Always:
#     - Max Supported macOS Version (SOFA) — upgrade planning vs the
#       software update Blueprints
#     - Days Since Last Reboot          — helpdesk triage
#     - Battery Cycle Count / Condition — hardware refresh planning
#     - Local Admin Accounts            — security audit
#     - Gatekeeper Status               — security posture
#     - Time Machine Last Backup        — backup visibility
#     - Jamf Connect Version
#   Stack-conditional:
#     - Huntress / SentinelOne agent version (matches edr_provider)
#     - Splashtop Streamer version (when enable_splashtop)

locals {
  baseline_extension_attributes = {
    max_supported_macos = {
      name        = "Max Supported macOS Version"
      description = "Highest macOS major version this model supports, via the SOFA feed (sofa.macadmins.io). Managed by Terraform."
      data_type   = "STRING"
      file        = "max_supported_macos.sh"
    }
    macos_upgrade_available = {
      name        = "macOS Upgrade Available"
      description = "Yes when this Mac runs a lower macOS major than its hardware supports (SOFA feed). Managed by Terraform."
      data_type   = "STRING"
      file        = "macos_upgrade_available.sh"
    }
    days_since_reboot = {
      name        = "Days Since Last Reboot"
      description = "Whole days since last boot. Managed by Terraform."
      data_type   = "INTEGER"
      file        = "days_since_reboot.sh"
    }
    battery_cycle_count = {
      name        = "Battery Cycle Count"
      description = "Battery cycle count (-1 = no battery/desktop). Managed by Terraform."
      data_type   = "INTEGER"
      file        = "battery_cycle_count.sh"
    }
    battery_condition = {
      name        = "Battery Condition"
      description = "Battery condition per system_profiler (Normal / Service Recommended / No Battery). Managed by Terraform."
      data_type   = "STRING"
      file        = "battery_condition.sh"
    }
    local_admin_accounts = {
      name        = "Local Admin Accounts"
      description = "Members of the local admin group (root and service accounts filtered). Managed by Terraform."
      data_type   = "STRING"
      file        = "local_admin_accounts.sh"
    }
    gatekeeper_status = {
      name        = "Gatekeeper Status"
      description = "Gatekeeper assessment status (Enabled/Disabled). Managed by Terraform."
      data_type   = "STRING"
      file        = "gatekeeper_status.sh"
    }
    time_machine_last_backup = {
      name        = "Time Machine Last Backup"
      description = "Date of the newest completed Time Machine backup, or configuration status. Managed by Terraform."
      data_type   = "STRING"
      file        = "time_machine_last_backup.sh"
    }
    # NOTE: no bootstrap-token EA — Jamf Pro tracks "Bootstrap Token
    # Escrowed" natively (VERIFIED live 2026-08-03: creating an EA with that
    # name collides with the built-in, and the smart group criterion works
    # without one).
    ddm_status = {
      name        = "DDM Status"
      description = "Declarative Device Management channel state (Enabled/Disabled/Unknown). Disabled Macs ignore update Blueprints. Managed by Terraform."
      data_type   = "STRING"
      file        = "ddm_status.sh"
    }
  }

  conditional_extension_attributes = merge(
    local.platform_sso_enabled ? {
      platform_sso_registration = {
        name        = "Platform SSO Registration"
        description = "Entra Platform SSO registration state of the console user (Registered / Not Registered). Managed by Terraform."
        data_type   = "STRING"
        file        = "platform_sso_registration.sh"
      }
    } : {},
    var.idp_provider != "none" ? {
      jamf_connect_version = {
        name        = "Jamf Connect Version"
        description = "Installed Jamf Connect app version. Managed by Terraform."
        data_type   = "STRING"
        file        = "jamf_connect_version.sh"
      }
    } : {},
    var.edr_provider == "huntress" ? {
      huntress_version = {
        name        = "Huntress Agent Version"
        description = "Installed Huntress agent version. Managed by Terraform."
        data_type   = "STRING"
        file        = "huntress_version.sh"
      }
    } : {},
    var.edr_provider == "sentinelone" ? {
      sentinelone_version = {
        name        = "SentinelOne Agent Version"
        description = "Installed SentinelOne agent version via sentinelctl. Managed by Terraform."
        data_type   = "STRING"
        file        = "sentinelone_version.sh"
      }
    } : {},
    var.enable_splashtop ? {
      splashtop_version = {
        name        = "Splashtop Streamer Version"
        description = "Installed Splashtop Streamer version. Managed by Terraform."
        data_type   = "STRING"
        file        = "splashtop_version.sh"
      }
    } : {}
  )

  extension_attributes = merge(local.baseline_extension_attributes, local.conditional_extension_attributes)
}

resource "jamfpro_computer_extension_attribute" "baseline" {
  for_each = local.extension_attributes

  name                   = each.value.name
  enabled                = true
  description            = each.value.description
  input_type             = "SCRIPT"
  data_type              = each.value.data_type
  inventory_display_type = "EXTENSION_ATTRIBUTES"
  script_contents        = file("${path.module}/scripts/ea/${each.value.file}")
}
