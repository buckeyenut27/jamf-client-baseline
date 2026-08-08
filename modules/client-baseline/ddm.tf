# DDM (Declarative Device Management) readiness — checker/fixer pack.
#
# Apple removes traditional MDM software update commands in Fall 2026; the
# update Blueprints this baseline deploys are DDM under the hood. A Mac only
# honors DDM enforcement when (a) its declarative channel is active and
# (b) on Apple silicon, a Bootstrap Token is escrowed to Jamf Pro. This file
# surfaces both and auto-remediates the first.
#
# The EAs live in extension_attributes.tf (bootstrap_token, ddm_status).
# NOTE: Jamf Pro 11.29 also ships native inventory fields for "Pending DDM
# Update Version" / "Scheduled DDM Update Deadline" — no custom EA needed
# for those.

# Macs whose declarative channel is not active — Blueprints can't reach them.
resource "jamfpro_smart_computer_group_v2" "ddm_not_enabled" {
  # Jamf's smart-group criterion list can lag EA creation (VERIFIED live
  # 2026-08-03: "criterion not valid" seconds after the EA was created —
  # a re-apply succeeds). depends_on makes the ordering explicit.
  depends_on = [jamfpro_computer_extension_attribute.baseline]

  name        = "DDM - Not Enabled"
  description = "Managed by Terraform. Macs reporting Declarative Device Management disabled - these ignore update Blueprints. Auto-remediated by the DDM - Kick Enrollment policy."

  criteria {
    name        = "DDM Status"
    priority    = 0
    and_or      = "and"
    search_type = "is"
    value       = "Disabled" # deliberately NOT "Unknown" - older macOS would loop the fixer forever
  }
}

# Apple silicon Macs that can't take DDM updates until a token is escrowed.
# No silent fix exists (escrow requires a secure-token admin login), so this
# group is the tech worklist, not a remediation target.
# Uses Jamf's NATIVE "Bootstrap Token Escrowed" criterion (VERIFIED live
# 2026-08-03) — no EA needed.
resource "jamfpro_smart_computer_group_v2" "bootstrap_token_missing" {
  name        = "Bootstrap Token - Not Escrowed"
  description = "Managed by Terraform. Macs without an escrowed Bootstrap Token - DDM software updates will not enforce on Apple silicon. Fix requires a secure-token admin login (no silent remediation)."

  criteria {
    name        = "Bootstrap Token Escrowed"
    priority    = 0
    and_or      = "and"
    search_type = "is"
    value       = "No"
  }
}

resource "jamfpro_script" "ddm_kick_enrollment" {
  name            = "DDM - Kick Enrollment"
  category_id     = jamfpro_category.security.id
  priority        = "AFTER"
  script_contents = file("${path.module}/scripts/ddm_kick_enrollment.sh")
  info            = "Re-syncs a stuck declarative management channel via profiles renew. Managed by Terraform - do not edit in the Jamf Pro UI."
  notes           = "Deployed by the the MSP client baseline."
}

resource "jamfpro_policy" "ddm_kick_enrollment" {
  name            = "DDM - Kick Enrollment"
  enabled         = true
  frequency       = "Once every day" # gentle retry - not every check-in
  trigger_checkin = true
  category_id     = tonumber(jamfpro_category.security.id)

  scope {
    all_computers      = false
    computer_group_ids = [tonumber(jamfpro_smart_computer_group_v2.ddm_not_enabled.id)]
  }

  payloads {
    scripts {
      id       = jamfpro_script.ddm_kick_enrollment.id
      priority = "After"
    }

    maintenance {
      recon = true # re-evaluate DDM Status so fixed Macs leave the group
    }
  }
}
