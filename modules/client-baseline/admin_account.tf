# MSP service admin (msp_admin) — HIDDEN local admin on EVERY Mac,
# for lockout protection and support work.
#
# Two creation paths guarantee coverage:
#   1. PreStage (prestage.tf): created during Setup Assistant on ADE Macs —
#      this copy also receives a Secure Token (can unlock FileVault).
#   2. This policy: self-healing catch-all for takeover Macs, Macs enrolled
#      before the PreStage existed, or anyone who deletes/demotes the account.
#      Re-runs at check-in while the account is missing; also repairs admin
#      membership and the hidden flag if the account exists but was tampered.
#
# The account is automatically excluded from Jamf Connect DenyLocal and
# hidden from Migrate (locals.tf), so it can always log in at the login
# window even with IdP-forced logins.
#
# Password: per-client, passed at runtime as Jamf script parameter 4 — never
# stored in the script body in Jamf Pro. Static per client (rotate via tfvars
# + apply). ASSUMPTION (check once): the smart group criterion "Local User
# Accounts" requires local-account inventory collection (Jamf default on).

resource "jamfpro_script" "create_msp_admin" {
  name            = "Create MSP Service Admin"
  category_id     = jamfpro_category.security.id
  priority        = "AFTER"
  script_contents = file("${path.module}/scripts/create_msp_admin.sh")
  info            = "Creates/repairs the hidden MSP service admin account. Managed by Terraform - do not edit in the Jamf Pro UI."
  notes           = "Deployed by the the MSP client baseline."

  parameter4 = "Account Password"
  parameter5 = "Account Username"
}

resource "jamfpro_smart_computer_group_v2" "msp_admin_missing" {
  name        = "MSP Admin - Missing"
  description = "Managed by Terraform. Macs without the ${var.msp_admin_username} service account."

  criteria {
    name        = "Local User Accounts"
    priority    = 0
    and_or      = "and"
    search_type = "does not have"
    value       = var.msp_admin_username
  }
}

resource "jamfpro_policy" "create_msp_admin" {
  name                        = "Create MSP Service Admin"
  enabled                     = true
  frequency                   = "Ongoing"
  trigger_checkin             = true
  trigger_enrollment_complete = true
  category_id                 = tonumber(jamfpro_category.security.id)

  scope {
    all_computers      = false
    computer_group_ids = [tonumber(jamfpro_smart_computer_group_v2.msp_admin_missing.id)]
  }

  payloads {
    scripts {
      id         = jamfpro_script.create_msp_admin.id
      priority   = "After"
      parameter4 = var.msp_admin_password
      parameter5 = var.msp_admin_username
    }

    maintenance {
      recon = true # drop out of the smart group immediately
    }
  }

  lifecycle {
    precondition {
      condition     = var.msp_admin_password != ""
      error_message = "msp_admin_password is empty. The MSP service admin is created on every Mac - set a per-client password in terraform.tfvars."
    }
  }
}
