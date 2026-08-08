# Fleet hygiene defaults (MSP standard).
#
# TENANT-WIDE SINGLETONS: like the Self Service settings, the check-in and
# inventory-collection resources own the tenant's settings — if someone
# changes them in the Jamf UI, the next apply puts them back. That is
# deliberate (MSP policy: the automation wins). Do NOT add ignore_changes.

# ── 1. Client check-in ───────────────────────────────────────────────────
resource "jamfpro_client_checkin" "tenant" {
  check_in_frequency = var.client_checkin_frequency

  create_startup_script = true
  startup_log           = true
  startup_policies      = true
  startup_ssh           = false # never force-enable Remote Login

  create_hooks  = true
  hook_log      = true
  hook_policies = true

  enable_local_configuration_profiles = true
  allow_network_state_change_triggers = true
}

# ── 2. Inventory collection ──────────────────────────────────────────────
# include_hidden_accounts is REQUIRED by this baseline: the hidden
# msp_admin account must appear in inventory or the "MSP Admin -
# Missing" smart group ("Local User Accounts does not have msp_admin")
# never empties and the self-healing policy loops forever.
resource "jamfpro_computer_inventory_collection_settings" "tenant" {
  computer_inventory_collection_preferences {
    include_accounts        = true
    include_hidden_accounts = true

    include_packages         = true
    include_software_id      = true
    include_software_updates = false # legacy feature; updates come from Blueprints
    calculate_sizes          = false
    include_printers         = false
    include_services         = false

    monitor_application_usage = false # privacy: no app-usage tracking by default
    monitor_beacons           = false

    collect_synced_mobile_device_info                  = false
    collect_unmanaged_certificates                     = true
    update_ldap_info_on_computer_inventory_submissions = true
    allow_changing_user_and_location                   = true
    use_unix_user_paths                                = false
  }
}

# ── 3. Weekly forced inventory ───────────────────────────────────────────
# EAs and smart groups are only as fresh as the last recon. Policies that
# run recon cover their own Macs; this catches everything else weekly.
resource "jamfpro_policy" "weekly_inventory" {
  name            = "Update Inventory (Weekly)"
  enabled         = true
  frequency       = "Once every week"
  trigger_checkin = true
  category_id     = tonumber(jamfpro_category.security.id)

  scope {
    all_computers      = false
    computer_group_ids = [local.all_managed_clients_group_id]
  }

  payloads {
    maintenance {
      recon = true
    }
  }
}

# ── 4. Compliance smart groups (built on the baseline EAs) ───────────────
# ASSUMPTION for all EA-based criteria: the criterion name is the EA's
# display name. If a group never populates, check the criterion picker in
# the Jamf UI.

resource "jamfpro_smart_computer_group_v2" "os_upgrade_available" {
  # Criterion list lags EA creation — see ddm.tf note.
  depends_on = [jamfpro_computer_extension_attribute.baseline]

  name        = "macOS - Upgrade Available"
  description = "Managed by Terraform. Macs running a lower macOS major than their hardware supports (SOFA). Upgrade-planning view."

  criteria {
    name        = "macOS Upgrade Available"
    priority    = 0
    and_or      = "and"
    search_type = "is"
    value       = "Yes"
  }
}

resource "jamfpro_smart_computer_group_v2" "battery_service" {
  name        = "Battery - Service Recommended"
  description = "Managed by Terraform. Macs whose battery condition is anything other than Normal - hardware refresh planning."

  criteria {
    name        = "Battery Condition"
    priority    = 0
    and_or      = "and"
    search_type = "is not"
    value       = "Normal"
  }

  criteria {
    name        = "Battery Condition"
    priority    = 1
    and_or      = "and"
    search_type = "is not"
    value       = "No Battery"
  }
}

resource "jamfpro_smart_computer_group_v2" "no_time_machine" {
  name        = "Backup - Time Machine Not Configured"
  description = "Managed by Terraform. Macs with no Time Machine destination configured - backup visibility, not enforcement."

  criteria {
    name        = "Time Machine Last Backup"
    priority    = 0
    and_or      = "and"
    search_type = "is"
    value       = "Not Configured"
  }
}

resource "jamfpro_smart_computer_group_v2" "stale_warning" {
  name        = "Stale - No Check-in 7+ Days (Warning)"
  description = "Managed by Terraform. Early-warning tier ahead of the 30-day stale group - investigate before devices go dark."

  criteria {
    name        = "Last Check-in"
    priority    = 0
    and_or      = "and"
    search_type = "more than x days ago"
    value       = "7"
  }
}
