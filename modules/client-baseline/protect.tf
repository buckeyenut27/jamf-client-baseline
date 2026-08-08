# Jamf Protect baseline:
#   1. Action configuration (what alert data is collected and where it goes)
#   2. Telemetry configuration (which endpoint events are logged)
#   3. Plan (the security posture deployed to Macs)
#   4. The plan's configuration profile, pushed to all Macs via Jamf Pro
#
# Schemas verified against the Jamf-Concepts/jamfprotect provider docs (v0.6.x).

resource "jamfprotect_action_configuration" "baseline" {
  count = var.enable_jamf_protect ? 1 : 0

  name        = "Baseline Action Configuration"
  description = "Managed by Terraform. Alert data enrichment with delivery to Jamf Protect cloud."

  alert_data_collection = {
    binary_included_data_attributes                = ["Sha256", "Signing Information"]
    download_event_included_data_attributes        = ["File"]
    file_included_data_attributes                  = ["Sha256", "Signing Information"]
    file_system_event_included_data_attributes     = ["File", "Process"]
    gatekeeper_event_included_data_attributes      = ["Blocked Process"]
    group_included_data_attributes                 = ["Name"]
    keylog_register_event_included_data_attributes = ["Source Process"]
    process_included_data_attributes               = ["Args", "Signing Information", "Binary", "User", "Parent"]
    process_event_included_data_attributes         = ["Process"]
    screenshot_event_included_data_attributes      = ["File"]
    synthetic_click_event_included_data_attributes = ["Process"]
    user_included_data_attributes                  = ["Name"]
  }

  jamf_protect_cloud_endpoint = {
    collect_alerts     = ["low", "medium", "high"]
    collect_logs       = ["telemetry"]
    destination_filter = null
  }
}

resource "jamfprotect_telemetry" "baseline" {
  count = var.enable_jamf_protect ? 1 : 0

  name        = "Baseline Telemetry"
  description = "Managed by Terraform. Security-focused telemetry collection."

  log_access_and_authentication  = true
  log_apple_security             = true
  log_persistence                = true
  log_users_and_groups           = true
  log_system                     = true
  log_hardware_and_software      = false
  log_applications_and_processes = true
  file_hashes                    = true
  log_file_path                  = []

  collect_performance_metrics          = false
  collect_diagnostic_and_crash_reports = true
}

# Tamper prevention support profile (macOS 15+): makes the Jamf Protect
# system extensions (Team ID 483DWKW443 — security extension + network
# content filter) non-removable from the UI, per Jamf's requirement for
# System/Tamper Prevention on macOS 15 and later. Source: Jamf-provided
# mobileconfig (signature stripped — Jamf Pro re-signs on delivery).
# Harmless on older macOS: the allowlist applies everywhere; the
# NonRemovableFromUI key is simply ignored pre-15.
resource "jamfpro_macos_configuration_profile_plist" "jamf_protect_tamper" {
  count = var.enable_jamf_protect ? 1 : 0

  name                = "Jamf Protect - Tamper Prevention (System Extensions)"
  description         = "Managed by Terraform. Allows and makes non-removable the Jamf Protect system extensions (macOS 15+ tamper prevention requirement)."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.security.id)
  payloads            = file("${path.module}/profiles/jamf_protect_tamper.mobileconfig")
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

# ── Exception sets ─────────────────────────────────────────────────────
# Huntress EDR coexistence (MSP standard, worked out live on the pilot tenant,
# 2026-07/08): Jamf Protect Threat Prevention flags Huntress binaries
# (read-only file hashing + persistence enumeration look like the behaviors
# it watches for). One Team ID rule covers every Huntress-signed binary —
# agent, updaters, system extension, EDRConnection XPC — including future
# ones. VERIFIED from live codesign output: all six Huntress binaries carry
# TeamIdentifier=7W6HQ9J9XA (Huntress Labs Inc). Do NOT use CDHash rules —
# they break silently on every Huntress auto-update.
#
# Requires legacy Threat Prevention (threat_prevention_strategy = "Legacy",
# the plan default): Jamf documents that the NGTP beta does not support
# Jamf-managed or custom exceptions yet.

data "jamfprotect_exception_sets" "all" {
  count = var.enable_jamf_protect ? 1 : 0
}

# Analytic sets — attached to the plan so legacy Threat Prevention actually
# alerts (an empty Analytic sets list = no analytic alerts, VERIFIED live on
# the pilot tenant 2026-08-03). The tenant's built-in/default analytic set is used
# (MSP standard): candidates are any Jamf-managed set plus any set whose
# name contains "default"; if the tenant has exactly one set, that one is
# used regardless of name. NOTE: Terraform owns the plan's analytic set
# list — sets added by hand in the console get detached on the next apply;
# add them here instead.
data "jamfprotect_analytic_sets" "all" {
  count = var.enable_jamf_protect ? 1 : 0
}

data "jamfprotect_analytics" "all" {
  count = var.enable_jamf_protect ? 1 : 0
}

locals {
  msp_analytic_set_name = "MSP Baseline Analytics"

  _all_analytic_sets = var.enable_jamf_protect ? data.jamfprotect_analytic_sets.all[0].analytic_sets : []

  # IMPORTANT: exclude OUR OWN set from the lookup — otherwise the set
  # Terraform created last apply satisfies the "found something" check,
  # count flips to 0, and Terraform destroys the very set it just attached
  # (near-miss caught live on the pilot tenant 2026-08-03).
  _other_analytic_sets = [
    for s in local._all_analytic_sets : s if s.name != local.msp_analytic_set_name
  ]

  _default_analytic_set_ids = [
    for s in local._other_analytic_sets :
    s.uuid if s.managed || strcontains(lower(s.name), "default")
  ]

  # Existing-set preference: managed/default-named set, else a tenant with
  # exactly one (non-MSP) set uses that one.
  found_analytic_set_ids = length(local._default_analytic_set_ids) > 0 ? local._default_analytic_set_ids : (
    length(local._other_analytic_sets) == 1 ? [local._other_analytic_sets[0].uuid] : []
  )

  # VERIFIED live (the pilot tenant, 2026-08-03): the Protect list API can return
  # ZERO analytic sets even when the console shows a default. When no other
  # set is findable via the API, create (and keep) our own baseline set from
  # every Jamf-managed analytic so the plan always alerts.
  create_baseline_analytic_set = var.enable_jamf_protect && length(local.found_analytic_set_ids) == 0

  jamf_managed_analytic_ids = var.enable_jamf_protect ? [
    for a in data.jamfprotect_analytics.all[0].analytics : a.id if a.jamf
  ] : []

  plan_analytic_set_ids = local.create_baseline_analytic_set ? [jamfprotect_analytic_set.baseline[0].id] : local.found_analytic_set_ids
}

resource "jamfprotect_analytic_set" "baseline" {
  count = local.create_baseline_analytic_set ? 1 : 0

  name        = local.msp_analytic_set_name
  description = "Managed by Terraform. Every Jamf-managed analytic - the MSP standard alerting baseline (created because the tenant exposed no analytic set via the API)."
  analytics   = toset(local.jamf_managed_analytic_ids)

  lifecycle {
    precondition {
      condition     = length(local.jamf_managed_analytic_ids) > 0
      error_message = "No Jamf-managed analytics returned by the Protect tenant - check the Protect API client role and tenant health."
    }
  }
}

locals {
  huntress_exception_set_name = "Huntress EDR Coexistence"

  # Jamf-managed default exception set(s) — always attached to the plan
  # (Jamf-maintained balance of protection vs. user-experience breakage).
  jamf_managed_exception_set_ids = var.enable_jamf_protect ? [
    for s in data.jamfprotect_exception_sets.all[0].exception_sets : s.uuid if s.managed
  ] : []

  # A pre-existing set with our standard name (e.g. created by hand in the
  # console before this automation ran — the pilot tenant). Attach it instead of
  # creating a duplicate.
  existing_huntress_set_ids = var.enable_jamf_protect ? [
    for s in data.jamfprotect_exception_sets.all[0].exception_sets :
    s.uuid if !s.managed && s.name == local.huntress_exception_set_name
  ] : []

  # Create our own set only for Huntress clients that don't already have one.
  create_huntress_exception_set = var.enable_jamf_protect && var.edr_provider == "huntress" && length(local.existing_huntress_set_ids) == 0
}

resource "jamfprotect_exception_set" "huntress_coexistence" {
  count = local.create_huntress_exception_set ? 1 : 0

  name        = local.huntress_exception_set_name
  description = "Managed by Terraform. Allows Huntress EDR (Team ID 7W6HQ9J9XA) to run alongside Jamf Protect - covers com.huntress.app, HuntressAgent, HuntressUpdater, HuntressMacUpdate, com.huntress.sysext, and EDRConnection. Reverse direction (allow-list Jamf Protect in the Huntress console) is a manual step."

  exceptions = [
    {
      type     = "Override Endpoint Threat Prevention"
      sub_type = "Process"
      rules = [
        {
          rule_type = "Team ID"
          value     = "7W6HQ9J9XA" # Huntress Labs Inc — VERIFIED via codesign
        }
      ]
    }
  ]
}

resource "jamfprotect_plan" "baseline" {
  count = var.enable_jamf_protect ? 1 : 0

  name        = "${var.client_name} Baseline Plan"
  description = "Managed by Terraform. Standard the MSP endpoint security posture (${var.jamf_protect_mode})."

  action_configuration = jamfprotect_action_configuration.baseline[0].id
  telemetry            = jamfprotect_telemetry.baseline[0].id

  # Jamf Managed Default Exceptions + the Huntress coexistence set
  # (existing-by-name or Terraform-created). Empty entries drop out.
  exception_sets = toset(concat(
    local.jamf_managed_exception_set_ids,
    local.existing_huntress_set_ids,
    local.create_huntress_exception_set ? [jamfprotect_exception_set.huntress_coexistence[0].id] : [],
  ))

  # The tenant's default analytic set(s) — see lookup above. Never attach an
  # empty set: the provider has an empty-set/null inconsistency bug (hit
  # live 2026-08-03), and the precondition below fails loudly instead.
  analytic_sets = toset(local.plan_analytic_set_ids)

  endpoint_threat_prevention = var.jamf_protect_mode
  advanced_threat_controls   = var.jamf_protect_mode
  tamper_prevention          = "Block and report"

  auto_update                   = true
  communications_protocol       = "MQTT:443"
  reporting_interval            = 1440
  compliance_baseline_reporting = true
  log_level                     = "Error"

  report_architecture  = true
  report_hostname      = true
  report_serial_number = true
  report_model_name    = true
  report_memory_size   = true

  lifecycle {
    precondition {
      condition     = length(local.plan_analytic_set_ids) > 0
      error_message = "No analytic set found to attach: the Protect tenant has no Jamf-managed set, no set named *default*, and not exactly one set. Create/rename a default analytic set in the Protect console (or adjust the lookup in protect.tf) - a plan with no analytic sets produces NO alerts."
    }
  }
}

# Jamf Protect generates the deployment profile for the plan...
#
# MSP POLICY (2026-08-01): profile deployment via this automation is OFF
# by default (deploy_jamf_protect_profile = false). The provider-generated
# profile has issues without the Platform-level API, so for now technicians
# deploy the plan's profile from the Jamf Protect console instead (Protect >
# Plans > <plan> > Deploy). The plan/telemetry/action config above are still
# fully managed here.
data "jamfprotect_plan_configuration_profile" "baseline" {
  count = var.enable_jamf_protect && var.deploy_jamf_protect_profile ? 1 : 0

  id           = jamfprotect_plan.baseline[0].id
  sign_profile = false

  include_pppc_payload                   = true
  include_system_extension_payload      = true
  include_login_background_items_payload = true
  include_websocket_authorizer_key       = true
  include_root_ca_certificate            = true
  include_csr_certificate                = true
  include_bootstrap_token                = true
}

# ...and Jamf Pro pushes it to every managed Mac.
# Jamf Protect regenerates this profile on every read, so changes to the
# payload are ignored after the first apply (per the provider docs).
resource "jamfpro_macos_configuration_profile_plist" "jamf_protect" {
  count = var.enable_jamf_protect && var.deploy_jamf_protect_profile ? 1 : 0

  name                = "Jamf Protect - ${var.client_name}"
  description         = "Managed by Terraform. Deploys the Jamf Protect agent configuration, PPPC, and system extension approvals."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.security.id)
  payloads            = base64decode(data.jamfprotect_plan_configuration_profile.baseline[0].profile)
  payload_validate    = false # profile is generated by Jamf Protect, not Jamf Pro
  user_removable      = false

  scope {
    all_computers      = false
    computer_group_ids = [local.all_managed_clients_group_id]
  }

  lifecycle {
    ignore_changes = [payloads]
  }
}
