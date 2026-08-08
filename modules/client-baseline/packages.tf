# Package uploads to the tenant's Jamf Cloud Distribution Service (JCDS).
#
# Installer pkgs live locally in the repo's packages/ folder; Terraform
# uploads them to the client tenant and attaches them to the right policy.
#
# PERMISSIONS NOTE (root/wheel): Jamf has no permissions setting on a package
# upload — there is nothing to configure here. File ownership inside a pkg
# (root:wheel) is baked in when the pkg is BUILT (in Composer: set Owner
# "root" / Group "wheel" before building), and Jamf's installer always runs
# the pkg as root. fill_user_template / fill_existing_users stay false (they
# only apply to DMG home-folder fills).

resource "jamfpro_package" "sentinelone" {
  count = var.edr_provider == "sentinelone" && var.sentinelone_package_path != "" ? 1 : 0

  package_name        = "SentinelOne Agent"
  package_file_source = var.sentinelone_package_path
  category_id         = jamfpro_category.security.id
  info                = "SentinelOne macOS agent installer. Managed by Terraform - uploaded to JCDS from the baseline repo."
  notes               = "the MSP client baseline."

  priority              = 10
  reboot_required       = false
  os_install            = false
  fill_user_template    = false
  fill_existing_users   = false
  suppress_updates      = false
  suppress_from_dock    = false
  suppress_eula         = false
  suppress_registration = false

  timeouts {
    create = "90m" # large uploads
  }
}

resource "jamfpro_package" "splashtop" {
  count = var.enable_splashtop && var.splashtop_package_path != "" ? 1 : 0

  package_name        = "Splashtop Streamer Deploy Assets"
  package_file_source = var.splashtop_package_path
  category_id         = jamfpro_category.remote_support.id
  info                = "Composer-built pkg that places the Splashtop deploy DMG and deploy_splashtop_streamer.sh at /private/tmp/SplashtopInstall/. Managed by Terraform."
  notes               = "the MSP client baseline."

  priority              = 10
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

# Optional: Huntress's official install script downloads the agent from
# huntress.io at runtime, so no package is required. If a pkg path is
# provided it is uploaded to JCDS as an offline fallback (not attached to
# any policy).
resource "jamfpro_package" "huntress" {
  count = var.edr_provider == "huntress" && var.huntress_package_path != "" ? 1 : 0

  package_name        = "Huntress Agent (offline fallback)"
  package_file_source = var.huntress_package_path
  category_id         = jamfpro_category.security.id
  info                = "Offline fallback only - the Install Huntress policy uses Huntress's self-downloading script. Managed by Terraform."
  notes               = "the MSP client baseline."

  priority              = 10
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
