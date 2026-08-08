# Microsoft Entra Platform SSO (Entra clients only).
#
# MSP standard: PSSO runs ALONGSIDE Jamf Connect — Jamf Connect owns the
# login window and account creation; PSSO owns app SSO into Microsoft 365,
# Entra device registration (Conditional Access), and password sync. The
# Jamf Connect menu bar profile stays disabled (default) so there is exactly
# one password-sync mechanism.
#
# Pieces:
#   1. Extensible SSO profile (Microsoft-documented values, Password method)
#   2. Company Portal pushed to all Macs via App Installers
#   3. "Platform SSO Registration" EA + "Not Registered" smart group so techs
#      can chase users who ignore the registration prompt
#
# User-facing note: after the profile and Company Portal land, each user gets
# a "Registration Required" notification and must sign in to Entra once.

locals {
  platform_sso_enabled = var.enable_platform_sso && var.idp_provider == "entra"
}

resource "jamfpro_macos_configuration_profile_plist" "platform_sso" {
  count = local.platform_sso_enabled ? 1 : 0

  name                = "Platform SSO - Microsoft Entra ID"
  description         = "Managed by Terraform. Entra Platform SSO via Company Portal: app SSO, device registration, password sync (Password method)."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.identity.id)
  payloads            = file("${path.module}/profiles/platform_sso_entra.mobileconfig")
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

# Company Portal hosts the SSO extension. Deployed per Jamf's official
# Platform SSO technical article: download the pkg from Microsoft, upload to
# Jamf Pro as a PACKAGE, deploy via policy — deliberately NOT App Installers.
# Why: PSSO fails on old Company Portal versions (Microsoft requires
# 5.2604.0+ for enrollment-time registration), the app must arrive EARLY
# (App Installers timing is not guaranteed at enrollment), and the catalog's
# version currency isn't under our control. Once installed, Company Portal
# keeps itself updated via Microsoft AutoUpdate (MAU).
# Download the current pkg from: https://go.microsoft.com/fwlink/?linkid=853070
resource "jamfpro_package" "company_portal" {
  count = local.platform_sso_enabled ? 1 : 0

  package_name        = "Microsoft Company Portal"
  package_file_source = var.company_portal_package_path
  category_id         = jamfpro_category.identity.id
  info                = "Microsoft Company Portal (hosts the Entra SSO extension for Platform SSO). Managed by Terraform - uploaded to JCDS from the baseline repo. Self-updates via Microsoft AutoUpdate after install."
  notes               = "the MSP client baseline."

  priority              = 5 # install early - PSSO depends on it
  reboot_required       = false
  os_install            = false
  fill_user_template    = false
  fill_existing_users   = false
  suppress_updates      = false
  suppress_from_dock    = false
  suppress_eula         = false
  suppress_registration = false

  timeouts {
    create = "90m"
  }
}

resource "jamfpro_smart_computer_group_v2" "company_portal_missing" {
  count = local.platform_sso_enabled ? 1 : 0

  name        = "Company Portal - Not Installed"
  description = "Managed by Terraform. Macs without the Microsoft Company Portal app (required for Platform SSO)."

  criteria {
    name        = "Application Title"
    priority    = 0
    and_or      = "and"
    search_type = "does not have"
    value       = "Company Portal.app"
  }
}

resource "jamfpro_policy" "install_company_portal" {
  count = local.platform_sso_enabled ? 1 : 0

  name                        = "Install Microsoft Company Portal"
  enabled                     = true
  frequency                   = "Ongoing"
  trigger_checkin             = true
  trigger_enrollment_complete = true
  category_id                 = tonumber(jamfpro_category.identity.id)

  scope {
    all_computers      = false
    computer_group_ids = [tonumber(jamfpro_smart_computer_group_v2.company_portal_missing[0].id)]
  }

  payloads {
    packages {
      distribution_point = "default"
      package {
        id     = tonumber(jamfpro_package.company_portal[0].id)
        action = "Install"
      }
    }

    maintenance {
      recon = true
    }
  }

  lifecycle {
    precondition {
      condition     = !local.platform_sso_enabled || var.company_portal_package_path != ""
      error_message = "enable_platform_sso is on for an Entra client but company_portal_package_path is empty. Download the current Company Portal pkg from https://go.microsoft.com/fwlink/?linkid=853070 into the repo's packages/ folder and set the path in terraform.tfvars."
    }
  }
}

# Macs whose console user has not completed PSSO registration.
# Criterion matches the "Platform SSO Registration" extension attribute.
resource "jamfpro_smart_computer_group_v2" "psso_not_registered" {
  count = local.platform_sso_enabled ? 1 : 0

  name        = "Platform SSO - Not Registered"
  description = "Managed by Terraform. Macs where the user has not completed Entra Platform SSO registration - follow up with the user."

  criteria {
    name        = "Platform SSO Registration"
    priority    = 0
    and_or      = "and"
    search_type = "is"
    value       = "Not Registered"
  }

  depends_on = [jamfpro_computer_extension_attribute.baseline]
}
