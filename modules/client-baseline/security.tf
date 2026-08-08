# Security baseline pack (enable_security_baseline):
#   1. FileVault — Individual recovery key escrowed to Jamf Pro, enforced by a
#      self-healing policy scoped to Macs that aren't encrypted
#   2. Screen lock profile — require password immediately after sleep/screen
#      saver, idle timeout configurable (default 15 min)
#   3. Firewall profile — macOS application firewall enabled
#   4. Stale-device smart group — no check-in for 30+ days

# ── 1. FileVault ─────────────────────────────────────────────

resource "jamfpro_disk_encryption_configuration" "filevault" {
  count = var.enable_security_baseline ? 1 : 0

  name                     = "FileVault - Individual Key (Escrowed)"
  key_type                 = "Individual"
  file_vault_enabled_users = "Current or Next User"

  # VERIFIED (live plan 2026-08-01): the server returns an empty
  # institutional_recovery_key block on every read (unused — key_type is
  # Individual). Without this, every plan shows phantom drift trying to
  # remove that empty block.
  lifecycle {
    ignore_changes = [institutional_recovery_key]
  }
}

# ASSUMPTION (check once): criteria name/value must match Jamf's built-in
# FileVault criterion. If this group never empties on encrypted Macs, check
# the criterion in the Jamf UI and adjust.
resource "jamfpro_smart_computer_group_v2" "filevault_off" {
  count = var.enable_security_baseline ? 1 : 0

  name        = "FileVault - Not Encrypted"
  description = "Managed by Terraform. Macs whose boot volume is not FileVault encrypted."

  criteria {
    name        = "FileVault 2 Partition Encryption State"
    priority    = 0
    and_or      = "and"
    search_type = "is not"
    value       = "Encrypted"
  }
}

resource "jamfpro_policy" "enable_filevault" {
  count = var.enable_security_baseline ? 1 : 0

  name            = "Enable FileVault"
  enabled         = true
  frequency       = "Ongoing"
  trigger_checkin = true
  category_id     = tonumber(jamfpro_category.security.id)

  scope {
    all_computers      = false
    computer_group_ids = [tonumber(jamfpro_smart_computer_group_v2.filevault_off[0].id)]
  }

  payloads {
    disk_encryption {
      action                           = "apply"
      disk_encryption_configuration_id = tonumber(jamfpro_disk_encryption_configuration.filevault[0].id)
      auth_restart                     = false
    }

    maintenance {
      recon = true
    }
  }

  # VERIFIED (live plan 2026-08-01): the provider defaults
  # remediate_key_type to "Individual" but the server drops the field when no
  # remediation configuration is attached (remediate id 0), so every plan
  # tries to re-add it. Ignore that one field — real policy changes still
  # plan normally.
  lifecycle {
    ignore_changes = [payloads[0].disk_encryption[0].remediate_key_type]
  }
}

# ── 2. Screen lock ───────────────────────────────────────────

resource "jamfpro_macos_configuration_profile_plist" "screen_lock" {
  count = var.enable_security_baseline ? 1 : 0

  name                = "Screen Lock - Require Password"
  description         = "Managed by Terraform. Screen saver after ${var.screen_lock_idle_minutes} minutes idle; password required immediately."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.security.id)
  payload_validate    = false
  user_removable      = false

  payloads = templatefile("${path.module}/templates/screen_lock.mobileconfig.tftpl", {
    idle_seconds = var.screen_lock_idle_minutes * 60
  })

  scope {
    all_computers      = false
    computer_group_ids = [local.all_managed_clients_group_id]
  }

  # VERIFIED (live apply 2026-08-01): Jamf Pro rewrites inner PayloadUUID/
  # PayloadIdentifier values when it stores a profile, so refresh always sees
  # drift and the provider refuses the resulting update (UUID mismatch). The
  # server copy is correct — ignore payload drift. To push a CONTENT change to
  # this profile later: terraform apply -replace=<resource address>.
  lifecycle {
    ignore_changes = [payloads]
  }
}

# ── 3. Firewall ──────────────────────────────────────────────

resource "jamfpro_macos_configuration_profile_plist" "firewall" {
  count = var.enable_security_baseline ? 1 : 0

  name                = "macOS Firewall - Enabled"
  description         = "Managed by Terraform. Enables the macOS application firewall (stealth mode off, incoming not blocked wholesale)."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.security.id)
  payloads            = file("${path.module}/profiles/firewall.mobileconfig")
  payload_validate    = false
  user_removable      = false

  scope {
    all_computers      = false
    computer_group_ids = [local.all_managed_clients_group_id]
  }

  # Jamf Pro rewrites inner payload UUIDs on save — see screen_lock note.
  lifecycle {
    ignore_changes = [payloads]
  }
}

# ── 4. Stale devices ─────────────────────────────────────────

resource "jamfpro_smart_computer_group_v2" "stale_devices" {
  count = var.enable_security_baseline ? 1 : 0

  name        = "Stale - No Check-in 30+ Days"
  description = "Managed by Terraform. Macs that have not checked in for 30 or more days - investigate or retire."

  criteria {
    name        = "Last Check-in"
    priority    = 0
    and_or      = "and"
    search_type = "more than x days ago"
    value       = "30"
  }
}
