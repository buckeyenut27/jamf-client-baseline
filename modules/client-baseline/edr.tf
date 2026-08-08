# EDR deployment — Huntress or SentinelOne, selected by var.edr_provider.
#
# Design:
#   - The install script body lives in scripts/<provider>_install.sh.
#   - Secrets (account key / site token) are NOT embedded in the script body.
#     They are passed at runtime as Jamf script parameters 4 and 5 from the
#     policy below, so they never appear in the script object in Jamf Pro.

# Huntress requires its PPPC / system extension / content filter approvals to
# be in place BEFORE the agent installs, so the install completes without user
# prompts. This is Huntress's official profile, verbatim:
# https://github.com/huntresslabs/deployment-scripts/blob/main/Bash/mac/HuntressSystemExtensionProfile.mobileconfig
# Scoped to all computers so it lands during enrollment, ahead of the
# check-in-triggered install policy.
resource "jamfpro_macos_configuration_profile_plist" "huntress_system_extension" {
  count = var.edr_provider == "huntress" ? 1 : 0

  name                = "Huntress - System Extension, PPPC & Content Filter"
  description         = "Managed by Terraform. Official Huntress MDM profile (FDA, system extension, web content filter, managed login items). Required before the Huntress agent installs."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.security.id)
  payloads            = file("${path.module}/profiles/huntress_system_extension.mobileconfig")
  payload_validate    = false # vendor-generated plist, not exported from Jamf Pro
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

# SentinelOne requires its system extension, network filter, Full Disk Access,
# notifications, and login-items approvals in place BEFORE the agent installs.
# Values match SentinelOne's documented MDM configuration (Team ID 4AYE5J54KN).
resource "jamfpro_macos_configuration_profile_plist" "sentinelone_prereqs" {
  count = var.edr_provider == "sentinelone" ? 1 : 0

  name                = "SentinelOne - System Extension, PPPC & Network Filter"
  description         = "Managed by Terraform. SentinelOne agent prerequisites: network extension approval, content filter, FDA for the S1 daemons, notifications, managed login items."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.security.id)
  payloads            = file("${path.module}/profiles/sentinelone_system_extension.mobileconfig")
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

resource "jamfpro_script" "edr_install" {
  count = local.edr_enabled ? 1 : 0

  name            = "Install ${local.edr_display_name}"
  category_id     = jamfpro_category.security.id
  priority        = "AFTER"
  script_contents = file("${path.module}/scripts/${var.edr_provider}_install.sh")
  info            = "Installs the ${local.edr_display_name} agent. Managed by Terraform - do not edit in the Jamf Pro UI."
  notes           = "Deployed by the the MSP client baseline."

  parameter4 = var.edr_provider == "huntress" ? "Huntress Account Key" : "SentinelOne Registration Token"
  parameter5 = var.edr_provider == "huntress" ? "Huntress Organization Key (blank = derive from tenant)" : "SentinelOne Package File Name (in Waiting Room)"
  parameter6 = var.edr_provider == "huntress" ? "Agent Tags (optional)" : null
  parameter7 = var.edr_provider == "huntress" ? "Reinstall (true/false)" : null
}

resource "jamfpro_policy" "edr_install" {
  count = local.edr_enabled ? 1 : 0

  # Ensure the EDR approval profile exists before the install policy
  # (whichever EDR is selected).
  depends_on = [
    jamfpro_macos_configuration_profile_plist.huntress_system_extension,
    jamfpro_macos_configuration_profile_plist.sentinelone_prereqs,
  ]

  name            = "Install ${local.edr_display_name}"
  enabled         = true
  frequency       = "Ongoing"
  trigger_checkin = true
  # NO enrollment-complete trigger — per Huntress's official Jamf Pro guide
  # (support.huntress.io article 41788352133267, checked 2026-08-01): the
  # system extension/PPPC profile MUST be on the Mac before the install
  # script runs, and recurring check-in "allows enough time for the
  # Configuration Policy to be applied". Firing at enrollment would race the
  # profile and produce a non-silent (or failed) agent install. Belt AND
  # suspenders: the scoping smart group also requires the profile to be
  # confirmed installed (see smart_groups.tf).
  category_id = tonumber(jamfpro_category.security.id)

  scope {
    all_computers      = false
    computer_group_ids = [tonumber(jamfpro_smart_computer_group_v2.edr_missing[0].id)]
  }

  payloads {
    # SentinelOne: cache the JCDS-uploaded pkg to the Jamf Waiting Room first;
    # the script then registers the token and installs it from there.
    dynamic "packages" {
      for_each = var.edr_provider == "sentinelone" && var.sentinelone_package_path != "" ? [1] : []
      content {
        distribution_point = "default"
        package {
          id     = tonumber(jamfpro_package.sentinelone[0].id)
          action = "Cache"
        }
      }
    }

    scripts {
      id         = jamfpro_script.edr_install[0].id
      priority   = "After"
      parameter4 = var.edr_provider == "huntress" ? var.huntress_account_key : var.sentinelone_site_token
      parameter5 = var.edr_provider == "huntress" ? var.huntress_organization_key : basename(var.sentinelone_package_path)
    }

    maintenance {
      recon = true # update inventory right away so the Mac drops out of the smart group
    }
  }

  lifecycle {
    precondition {
      condition     = var.edr_provider != "sentinelone" || var.sentinelone_package_path != ""
      error_message = "edr_provider is 'sentinelone' but sentinelone_package_path is empty. Put the S1 pkg in the repo's packages/ folder and set sentinelone_package_path in terraform.tfvars."
    }
  }
}
