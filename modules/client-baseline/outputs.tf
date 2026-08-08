output "summary" {
  description = "What was deployed for this client."
  value = {
    client            = var.client_name
    edr               = var.edr_provider
    idp               = var.idp_provider
    jamf_protect      = var.enable_jamf_protect ? "plan/telemetry/action config managed (${var.jamf_protect_mode}); profile ${var.deploy_jamf_protect_profile ? "deployed via Jamf Pro" : "NOT deployed - push it from the Protect console (MSP standard for now)"}" : "skipped"
    protect_exceptions = var.enable_jamf_protect ? "Jamf Managed Defaults attached${var.edr_provider == "huntress" || length(local.existing_huntress_set_ids) > 0 ? " + Huntress EDR Coexistence (Team ID 7W6HQ9J9XA)" : ""}" : "n/a"
    jamf_protect_plan = var.enable_jamf_protect ? jamfprotect_plan.baseline[0].name : "n/a"
    splashtop         = var.enable_splashtop ? "deployed" : "skipped"
    self_service_apps = sort(values(local.app_installer_titles))
    common_apps_self_service = sort([for a in values(local.common_apps_effective) : a.title if !a.installed_only])
    common_apps_update_only  = sort([for a in values(local.common_apps_effective) : a.title if a.installed_only])
    common_apps_scope        = var.common_apps_scope
    onepassword              = var.is_1password_customer ? "pushed to all Macs" : "not deployed"
    self_service_plus        = "enabled tenant-wide, auto-installed on all Macs (no VPP)"
    platform_features          = "Blueprints / passcode / CIS live in the optional platform module - see the 'platform_summary' output when platform.tf is enabled, else skipped"
    extension_attributes       = sort([for ea in values(local.extension_attributes) : ea.name])
    security_baseline          = var.enable_security_baseline ? "FileVault+escrow, screen lock (${var.screen_lock_idle_minutes}m), firewall, stale-device group" : "skipped"
    prestage                   = var.enable_prestage ? "ADE PreStage (default, Recovery Lock RANDOM, no minimum OS)" : "skipped"
    msp_admin               = "hidden service admin '${var.msp_admin_username}' on every Mac (PreStage + self-healing policy)"
    platform_sso               = local.platform_sso_enabled ? "Entra PSSO alongside Jamf Connect (Password method, Company Portal pushed)" : "skipped (Entra clients only)"
    app_suite         = "${var.app_suite} -> ${local.effective_app_suite}"
    categories        = [jamfpro_category.security.name, jamfpro_category.remote_support.name, jamfpro_category.identity.name, jamfpro_category.apps.name]
  }
}

output "manual_steps_remaining" {
  description = "Things Terraform cannot do — finish these in the consoles."
  value = [
    "0. PreStage prerequisite (one time, BEFORE first apply if enable_prestage): link the client's Apple Business Manager to Jamf Pro under Settings > Automated Device Enrollment. Also note APNs/ABM/VPP tokens renew annually - calendar it.",
    "1. If using Jamf Connect (idp_provider entra/google): deploy the Jamf Connect app via Jamf Pro > Settings > App Installers — Terraform configures Jamf Connect, it does not install the app. Skip when idp_provider = none.",
    "1b. Jamf Protect profile (unless deploy_jamf_protect_profile = true): deploy the plan's configuration profile FROM THE PROTECT CONSOLE — Protect > Plans > '${var.client_name} Baseline Plan' > deploy to Jamf Pro, scoped to All Managed Clients. Terraform manages the plan itself but not the profile (known provider issues without the Platform-level API).",
    "2. SentinelOne / Splashtop packages: nothing extra — Terraform uploaded them to JCDS from the repo's packages/ folder and attached them to the policies. Verify the upload shows 'Available' under Settings > Packages.",
    "3. Keep the packages/ folder current: drop in new vendor pkg versions and update the *_package_path values in tfvars, then re-apply.",
    "4. If using Huntress: the official Huntress system extension/PPPC profile AND the Jamf Protect exception set (Team ID 7W6HQ9J9XA) are deployed by Terraform automatically. MANUAL: reverse direction — in the Huntress console, allow-list Jamf Protect (Team ID 483DWKW443, app com.jamf.protect.daemon). Huntress has no API for exclusions, so this cannot be automated.",
    "5. Set inventory display columns (no API exists - manual, per Jamf Pro account): Computers = Computer Name, Serial Number, Username, Model, Last Check-in, Last Inventory Update; Devices = Display Name, Serial Number, Username, Model, Last Inventory Update. See README Step 5.",
    "6. Enroll a test Mac and confirm: Protect profile installs, EDR installs and drops out of its smart group, Self Service shows the app catalog, Jamf Connect login works with ${local.idp_display_name}.",
    "7. Entra + Platform SSO: after login, the user gets a one-time 'Registration Required' notification - sign in to Entra to complete PSSO registration. Macs that skip it appear in the 'Platform SSO - Not Registered' smart group after next inventory.",
  ]
}
