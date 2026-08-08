# Tenant-wide Self Service settings — applied to every client.
#
# 1. Self Service+ as the default end-user application. This is the
#    tenant-wide checkbox (Jamf Pro > Settings > Self Service+). Deploying it
#    this way has no VPP / Apple App Store requirement, and Jamf uninstalls
#    Self Service classic from devices automatically.
# 2. Install automatically on all Macs — no user action needed.
#
# NOTE: these are singleton tenant settings (one per Jamf Pro instance), not
# per-object resources. Terraform manages the tenant's single settings record.
#
# OWNERSHIP POLICY (MSP standard): Terraform OWNS tenant-wide settings.
# If a value was already set in the tenant, the first apply overwrites it;
# if someone changes it in the Jamf UI later, the next `terraform apply`
# reverts it. Do NOT add ignore_changes to these resources — that would
# surrender ownership.

resource "jamfpro_self_service_plus_settings" "tenant" {
  enabled = true
}

resource "jamfpro_self_service_settings" "tenant" {
  install_automatically = true
  install_location      = "/Applications"

  user_login_level        = "NotRequired"
  allow_remember_me       = true
  use_fido2               = false
  auth_type               = "Basic"
  notifications_enabled   = true
  alert_user_approved_mdm = true

  default_landing_page     = "HOME"
  default_home_category_id = -1
  bookmarks_name           = "Bookmarks"
}
