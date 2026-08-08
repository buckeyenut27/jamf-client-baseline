# Automated Device Enrollment (ADE / zero-touch) PreStage.
#
# PREREQUISITE (manual, per tenant): the client's Apple Business Manager must
# be linked to Jamf Pro first (Settings > Automated Device Enrollment —
# download the public key, upload to ABM, upload the server token to Jamf).
# Terraform references that ADE instance by ID (ade_instance_id, usually "1"
# for the first/only token in a fresh tenant).
#
# MSP defaults: mandatory + non-removable MDM, consumer setup panes
# skipped, FileVault pane skipped (the baseline enforces FileVault via policy
# instead), Recovery Lock enabled with a Jamf-managed random password,
# no minimum OS at enrollment (updates are enforced post-enrollment by the
# Blueprints), hidden msp_admin service account (this PreStage copy gets
# a Secure Token; admin_account.tf self-heals Macs that miss it).

resource "jamfpro_computer_prestage_enrollment" "baseline" {
  count = var.enable_prestage ? 1 : 0

  display_name     = "${var.client_name} - MSP Baseline"
  default_prestage = true
  mandatory        = true
  mdm_removable    = false

  support_phone_number  = "" # MSP policy: no support phone shown at enrollment
  support_email_address = var.support_email
  department            = ""

  enrollment_site_id                 = "-1"
  site_id                            = "-1"
  keep_existing_site_membership      = false
  keep_existing_location_information = false
  require_authentication             = false
  authentication_prompt              = ""

  prevent_activation_lock             = true
  enable_device_based_activation_lock = false

  device_enrollment_program_instance_id = var.ade_instance_id

  skip_setup_items {
    accessibility               = false
    additional_privacy_settings = true
    appearance                  = true
    apple_id                    = true
    biometric                   = false
    diagnostics                 = true
    display_tone                = true
    enable_lockdown_mode        = true
    file_vault                  = true # baseline enforces FileVault via policy + escrow
    icloud_diagnostics          = true
    icloud_storage              = true
    intelligence                = true
    location                    = false
    os_showcase                 = true
    payment                     = true
    privacy                     = false
    registration                = true
    restore                     = true
    screen_time                 = true
    siri                        = true
    software_update             = true # baseline enforces updates via Blueprints
    terms_of_address            = true
    tos                         = false
    wallpaper                   = true
    welcome                     = false
  }

  location_information {
    username      = ""
    realname      = ""
    phone         = ""
    email         = ""
    room          = ""
    position      = ""
    department_id = "-1"
    building_id   = "-1"
  }

  purchasing_information {
    leased             = false
    purchased          = true
    apple_care_id      = ""
    po_number          = ""
    vendor             = ""
    purchase_price     = ""
    life_expectancy    = 0
    purchasing_account = ""
    purchasing_contact = ""
    lease_date         = "1970-01-01"
    po_date            = "1970-01-01"
    warranty_date      = "1970-01-01"
  }

  # Entra Platform SSO (when enabled): tells the PreStage which app provides
  # the SSO extension so registration can be encouraged from enrollment.
  platform_sso_enabled       = local.platform_sso_enabled
  platform_sso_app_bundle_id = local.platform_sso_enabled ? "com.microsoft.CompanyPortalMac" : null

  anchor_certificates                  = []
  enrollment_customization_id          = "0"
  language                             = ""
  region                               = ""
  auto_advance_setup                   = false
  install_profiles_during_setup        = true
  prestage_installed_profile_ids       = []
  custom_package_ids                   = []
  custom_package_distribution_point_id = "-1"

  enable_recovery_lock          = true
  recovery_lock_password_type   = "RANDOM" # Jamf-managed, viewable per device in inventory
  recovery_lock_password        = ""
  rotate_recovery_lock_password = false

  # MSP policy: no minimum OS enforced at enrollment - the software update
  # Blueprints bring devices current after they enroll.
  prestage_minimum_os_target_version_type = "NO_ENFORCEMENT"
  minimum_os_specific_version             = ""

  account_settings {
    payload_configured                           = true
    local_admin_account_enabled                  = true # msp_admin on every Mac (MSP standard)
    admin_username                               = var.msp_admin_username
    admin_password                               = var.msp_admin_password
    hidden_admin_account                         = true # hidden service account
    local_user_managed                           = false
    user_account_type                            = "ADMINISTRATOR"
    prefill_primary_account_info_feature_enabled = false
    prefill_type                                 = "UNKNOWN"
    prefill_account_full_name                    = ""
    prefill_account_user_name                    = ""
    prevent_prefill_info_from_modification       = false
  }

  lifecycle {
    precondition {
      condition     = var.msp_admin_password != ""
      error_message = "msp_admin_password is empty - the MSP service admin is created on every Mac. Set a per-client password in terraform.tfvars."
    }
  }
}
