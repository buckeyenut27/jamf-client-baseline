output "summary" {
  description = "What the Platform module deployed for this client."
  value = {
    software_update_blueprints = var.enable_software_update_blueprints ? "minor: ${var.software_update_minor_days}d (ignore major) / major: ${var.software_update_major_days}d, install at ${var.software_update_install_time}" : "skipped"
    passcode_policy            = var.enable_passcode_blueprint ? "min length ${var.passcode_min_length}, 10 attempts, 15m inactivity" : "skipped"
    cis_benchmark              = var.enable_cis_benchmark ? "CIS Level 1, all controls, MONITOR (report only - never enforced at build)" : "skipped"
  }
}
