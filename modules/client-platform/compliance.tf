# CIS Level 1 Compliance Benchmark — REPORT ONLY (MSP standard).
#
# POLICY: enforcement_mode is hardcoded to "MONITOR" and is deliberately NOT
# a variable. This automation never enforces CIS at build — it reports on all
# Level 1 controls so compliance posture is visible per client. If a client
# later wants enforcement, that is a separate, deliberate change (note:
# enforcement_mode is immutable — switching to MONITOR_AND_ENFORCE replaces
# the benchmark).
#
# All CIS L1 rules are enabled for reporting. Safe in MONITOR mode: nothing
# is remediated or changed on devices; rules only produce compliance data.
#
# Creation is asynchronous — the provider polls until the benchmark reaches
# SYNCED, hence the generous create timeout.

data "jamfplatform_cbengine_rules" "cis_lvl1" {
  count = var.enable_cis_benchmark ? 1 : 0

  baseline_id = "cis_lvl1"
}

resource "jamfplatform_cbengine_benchmark" "cis_lvl1_monitor" {
  count = var.enable_cis_benchmark ? 1 : 0

  title              = "CIS Level 1 - Report Only"
  description        = "Managed by Terraform. All CIS Level 1 controls in MONITOR (report-only) mode. MSP policy: never enforced at build."
  source_baseline_id = "cis_lvl1"

  # NOTE (verified against released provider, June 2026): `sources` is
  # computed/read-only in the released provider — it derives mSCP sources
  # from source_baseline_id itself. Do not set it (docs on the repo's main
  # branch lag the release and still show it as settable).

  rules = [
    for r in data.jamfplatform_cbengine_rules.cis_lvl1[0].rules : {
      id      = r.id
      enabled = true # all controls report
    }
  ]

  target_device_groups = [local.swu_group_ids[0]]
  enforcement_mode     = "MONITOR" # report only — hardcoded by MSP policy

  timeouts = {
    create = "45m"
  }

  lifecycle {
    precondition {
      condition     = length(local.swu_group_ids) > 0
      error_message = "No Platform device group named '${var.software_update_device_group_name}' was found. Check software_update_device_group_name in terraform.tfvars."
    }
  }
}
