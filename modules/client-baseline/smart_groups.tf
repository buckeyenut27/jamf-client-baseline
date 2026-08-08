# Smart groups used to self-heal agent installs.
# Policies below are scoped to these groups with frequency "Ongoing":
# a Mac stays in the group (and keeps retrying the install at check-in)
# until the app shows up in its inventory.

resource "jamfpro_smart_computer_group_v2" "edr_missing" {
  count = local.edr_enabled ? 1 : 0

  name        = "${local.edr_display_name} - Not Installed"
  description = "Managed by Terraform. Macs that do not yet have ${local.edr_display_name} installed but HAVE received its system extension/PPPC profile (profile-first ordering per the vendor's Jamf Pro deployment guide)."

  criteria {
    name        = "Application Title"
    priority    = 0
    and_or      = "and"
    search_type = "does not have"
    value       = local.edr_app_title
  }

  # Profile-first gate (Huntress Jamf Pro guide, article 41788352133267):
  # the agent install must not run until the system extension/PPPC profile
  # is confirmed on the Mac, so silent install works. Referencing the
  # profile resource's name also guarantees Terraform creates the profile
  # before this group.
  # ASSUMPTION: computer smart-group criterion name "Profile Name" — if
  # this group never populates on Macs that show the profile in Device
  # Management, check the exact criterion name in the Jamf UI and adjust.
  criteria {
    name        = "Profile Name"
    priority    = 1
    and_or      = "and"
    search_type = "has"
    value       = var.edr_provider == "huntress" ? jamfpro_macos_configuration_profile_plist.huntress_system_extension[0].name : jamfpro_macos_configuration_profile_plist.sentinelone_prereqs[0].name
  }
}

resource "jamfpro_smart_computer_group_v2" "splashtop_missing" {
  count = var.enable_splashtop ? 1 : 0

  name        = "Splashtop Streamer - Not Installed"
  description = "Managed by Terraform. Macs that do not yet have Splashtop Streamer installed."

  criteria {
    name        = "Application Title"
    priority    = 0
    and_or      = "and"
    search_type = "does not have"
    value       = "Splashtop Streamer.app"
  }
}
