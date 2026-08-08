# Splashtop Streamer deployment scaffolding.
# The deploy code is passed at runtime as Jamf script parameter 4 — it is not
# stored in the script body in Jamf Pro.

# Splashtop Streamer privacy permissions (Team ID CPQQ3AW49Y): Accessibility
# and Full Disk Access granted silently; Screen Recording set so any standard
# user can approve it (macOS does not allow silent MDM approval of screen
# recording — that's an Apple platform restriction, not a profile gap).
resource "jamfpro_macos_configuration_profile_plist" "splashtop_pppc" {
  count = var.enable_splashtop ? 1 : 0

  name                = "Splashtop Streamer - PPPC"
  description         = "Managed by Terraform. Accessibility + Full Disk Access granted; Screen Recording approvable by standard users."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.remote_support.id)
  payloads            = file("${path.module}/profiles/splashtop_pppc.mobileconfig")
  payload_validate    = false # hand-built plist, not exported from Jamf Pro
  user_removable      = false

  scope {
    all_computers      = false
    computer_group_ids = [local.all_managed_clients_group_id]
  }

  # Jamf Pro rewrites inner payload UUIDs on save (VERIFIED live 2026-08-01) —
  # ignore payload drift; push content changes with terraform apply -replace.
  lifecycle {
    ignore_changes = [payloads]
  }
}

# Auto-updates for policy-installed Streamers via App Installers.
# Catalog title "Splashtop Streamer" VERIFIED against the live catalog
# (the pilot tenant tenant, 2026-08-01). Scoped to Macs that ALREADY have the
# Streamer — deliberately NOT All Managed Clients: the catalog installer is
# vanilla (no deploy code), so first installs must come from the Terraform
# policy below (which registers the Mac to the client's Splashtop team).
# Updates to an already-registered Streamer preserve registration.
resource "jamfpro_smart_computer_group_v2" "has_splashtop" {
  count = var.enable_splashtop ? 1 : 0

  name        = "Has Splashtop Streamer"
  description = "Managed by Terraform. Macs with Splashtop Streamer installed (auto-updated by App Installers)."

  criteria {
    name        = "Application Title"
    priority    = 0
    and_or      = "and"
    search_type = "has"
    value       = "Splashtop Streamer.app"
  }
}

resource "jamfpro_app_installer" "splashtop_streamer" {
  count = var.enable_splashtop ? 1 : 0

  name            = "Splashtop Streamer"
  app_title_name  = "Splashtop Streamer"
  enabled         = true
  deployment_type = "SELF_SERVICE"
  update_behavior = "AUTOMATIC"
  category_id     = jamfpro_category.remote_support.id
  site_id         = "-1"
  smart_group_id  = jamfpro_smart_computer_group_v2.has_splashtop[0].id

  install_predefined_config_profiles = true
  trigger_admin_notifications        = false

  self_service_settings {
    include_in_featured_category   = false
    include_in_compliance_category = false
    force_view_description         = false
    description                    = "Splashtop Streamer — kept up to date by IT. Managed by Terraform."

    categories {
      id       = jamfpro_category.remote_support.id
      featured = false
    }
  }

  # Server auto-populates notification_settings — see apps.tf common_apps note.
  lifecycle {
    ignore_changes = [notification_settings]
  }
}

resource "jamfpro_script" "splashtop_install" {
  count = var.enable_splashtop ? 1 : 0

  name            = "Install Splashtop Streamer"
  category_id     = jamfpro_category.remote_support.id
  priority        = "AFTER"
  script_contents = file("${path.module}/scripts/splashtop_install.sh")
  info            = "Installs Splashtop Streamer with this client's deploy code. Managed by Terraform - do not edit in the Jamf Pro UI."
  notes           = "Deployed by the the MSP client baseline."

  parameter4 = "Splashtop Deploy Code"
}

resource "jamfpro_policy" "splashtop_install" {
  count = var.enable_splashtop ? 1 : 0

  # PPPC approvals should exist before the Streamer installs.
  depends_on = [jamfpro_macos_configuration_profile_plist.splashtop_pppc]

  name                        = "Install Splashtop Streamer"
  enabled                     = true
  frequency                   = "Ongoing"
  trigger_checkin             = true
  trigger_enrollment_complete = true
  category_id                 = tonumber(jamfpro_category.remote_support.id)

  scope {
    all_computers      = false
    computer_group_ids = [tonumber(jamfpro_smart_computer_group_v2.splashtop_missing[0].id)]
  }

  payloads {
    # Install the JCDS-uploaded deploy-assets pkg first (places the DMG and
    # deploy script at /private/tmp/SplashtopInstall/); the script payload
    # runs After and performs the registered silent install.
    dynamic "packages" {
      for_each = var.splashtop_package_path != "" ? [1] : []
      content {
        distribution_point = "default"
        package {
          id     = tonumber(jamfpro_package.splashtop[0].id)
          action = "Install"
        }
      }
    }

    scripts {
      id         = jamfpro_script.splashtop_install[0].id
      priority   = "After"
      parameter4 = var.splashtop_deploy_code
    }

    maintenance {
      recon = true
    }
  }

  lifecycle {
    precondition {
      condition     = !var.enable_splashtop || var.splashtop_package_path != ""
      error_message = "enable_splashtop is true but splashtop_package_path is empty. Put the Composer-built Streamer deploy pkg in the repo's packages/ folder and set splashtop_package_path in terraform.tfvars."
    }
  }
}
