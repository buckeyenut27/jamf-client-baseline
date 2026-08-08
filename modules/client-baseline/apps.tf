# Self Service apps via Jamf App Installers.
#
# All apps below are deployed with the same settings (per MSP standard):
#   - Available in Self Service (users install when they want)
#   - Updates fully automatic
#   - "Install supporting configuration profiles" checked
#   - Scoped to smart group ID 1 = built-in "All Managed Clients"
#
# Core apps are always created. The productivity suite depends on app_suite:
#   "auto" (default) — follow the client's IdP: Entra -> Microsoft 365 suite,
#                      Google Workspace -> Google apps
#   "microsoft" / "google" / "none" — explicit override
#
# All app_title_name values below are VERIFIED against Jamf's official
# App Installers Software Titles list (learn.jamf.com, checked June 2026).
# If Jamf renames a title later, apply fails with a clear lookup error —
# check the current spelling in Jamf Pro > Mac Apps > App Installers and fix
# the map here.
#
# NOTE on Google: most Google Workspace apps (Docs, Sheets, Slides, Gmail) are
# web apps with no macOS desktop app, so the installable Google suite is small.
# Add more titles to google_app_titles if the client needs them and they exist
# in the Jamf App Catalog.

locals {
  microsoft_app_titles = {
    ms_word       = "Microsoft Word 365"
    ms_excel      = "Microsoft Excel 365"
    ms_powerpoint = "Microsoft PowerPoint 365"
    ms_outlook    = "Microsoft Outlook 365"
    ms_onenote    = "Microsoft OneNote 365"
    ms_onedrive   = "Microsoft OneDrive"
  }

  google_app_titles = {
    google_drive = "Google Drive" # Drive for desktop (syncs Docs/Sheets/Slides)
  }

  core_app_titles = {
    acrobat_reader = "Adobe Acrobat Reader (Unified) DC Continuous"
    ms_teams       = "Microsoft Teams"
    zoom           = "Zoom Client for Meetings"
    chrome         = "Google Chrome"
  }

  # "Common apps" — auto-patched by App Installers on every client. Each entry
  # also gets a "Has <app>" smart group.
  #   title          = Jamf App Catalog title (VERIFIED June 2026)
  #   app            = app name in Jamf inventory, used for the "Has" smart
  #                    group (ASSUMPTION — verify on a real Mac if a group
  #                    stays empty)
  #   installed_only = true  -> deployment scoped to the "Has <app>" group:
  #                    auto-updates existing installs, NOT shown in Self
  #                    Service to users who don't have it (MSP standard for
  #                    AI apps).
  #                    false -> visible to everyone in Self Service and
  #                    auto-patched wherever installed.
  common_apps = {
    canva       = { title = "Canva", app = "Canva.app", installed_only = false }
    slack       = { title = "Slack", app = "Slack.app", installed_only = false }
    vscode      = { title = "Microsoft Visual Studio Code", app = "Visual Studio Code.app", installed_only = false }
    whatsapp    = { title = "WhatsApp", app = "WhatsApp.app", installed_only = false }
    ringcentral = { title = "RingCentral App", app = "RingCentral.app", installed_only = false }

    # AI apps — update-only, hidden from Self Service for users without them:
    claude  = { title = "Claude Desktop", app = "Claude.app", installed_only = true }
    # VERIFIED (live apply 2026-08-01): catalog title is "OpenAI ChatGPT
    # Classic" (the desktop app — OpenAI renamed it when Atlas/Codex shipped).
    chatgpt = { title = "OpenAI ChatGPT Classic", app = "ChatGPT.app", installed_only = true }
    copilot = { title = "Microsoft 365 Copilot", app = "Microsoft 365 Copilot.app", installed_only = true }
    gemini  = { title = "Google Gemini", app = "Google Gemini.app", installed_only = true }
    cursor  = { title = "Cursor AI", app = "Cursor.app", installed_only = true }

    # MSP-recommended additions (high-churn apps worth auto-patching):
    firefox = { title = "Mozilla Firefox", app = "Firefox.app", installed_only = false }
    edge    = { title = "Microsoft Edge", app = "Microsoft Edge.app", installed_only = false }
    notion  = { title = "Notion", app = "Notion.app", installed_only = false }
    dropbox = { title = "Dropbox", app = "Dropbox.app", installed_only = false }
    vlc     = { title = "VLC media player", app = "VLC.app", installed_only = false }

    # ── Patch-management net (added 2026-08-01) ──────────────────────────
    # Update-only across the board: auto-patched wherever found, never shown
    # in Self Service to users who don't have them. Titles VERIFIED against
    # the live App Installers catalog (the pilot tenant tenant, 2026-08-01); bundle
    # names are ASSUMPTIONS — if a "Has <app>" group stays empty on a Mac
    # that has the app, check the app name in Jamf inventory and fix here.

    # Browsers:
    brave = { title = "Brave Browser", app = "Brave Browser.app", installed_only = true }
    arc   = { title = "Arc", app = "Arc.app", installed_only = true }
    opera = { title = "Opera", app = "Opera.app", installed_only = true }

    # Meetings & communication:
    webex     = { title = "Cisco Webex", app = "Webex.app", installed_only = true }
    discord   = { title = "Discord", app = "Discord.app", installed_only = true }
    signal    = { title = "Signal", app = "Signal.app", installed_only = true }
    loom      = { title = "Loom", app = "Loom.app", installed_only = true }
    dialpad   = { title = "Dialpad", app = "Dialpad.app", installed_only = true }
    messenger = { title = "Facebook Messenger", app = "Messenger.app", installed_only = true }

    # Productivity & design:
    grammarly = { title = "Grammarly Desktop", app = "Grammarly Desktop.app", installed_only = true }
    obsidian  = { title = "Obsidian", app = "Obsidian.app", installed_only = true }
    evernote  = { title = "Evernote", app = "Evernote.app", installed_only = true }
    figma     = { title = "Figma", app = "Figma.app", installed_only = true }
    miro      = { title = "Miro", app = "Miro.app", installed_only = true }
    asana     = { title = "Asana", app = "Asana.app", installed_only = true }
    clickup   = { title = "ClickUp", app = "ClickUp.app", installed_only = true }
    spotify   = { title = "Spotify", app = "Spotify.app", installed_only = true }

    # Password managers (1Password stays a separate per-client toggle):
    bitwarden = { title = "Bitwarden", app = "Bitwarden.app", installed_only = true }
    keeper    = { title = "Keeper Password Manager", app = "Keeper Password Manager.app", installed_only = true }

    # Cloud storage (Google Drive deduped automatically for Google-suite
    # clients — see common_apps_effective below):
    google_drive = { title = "Google Drive", app = "Google Drive.app", installed_only = true }
    box_drive    = { title = "Box Drive", app = "Box.app", installed_only = true }

    # PDF:
    foxit = { title = "Foxit PDF Editor", app = "Foxit PDF Editor.app", installed_only = true }

    # AI (joins the update-only AI set above):
    perplexity = { title = "Perplexity", app = "Perplexity.app", installed_only = true }
  }

  # "auto" follows the IdP; idp_provider "none" means no suite on auto.
  effective_app_suite = var.app_suite == "auto" ? {
    entra  = "microsoft"
    google = "google"
    none   = "none"
  }[var.idp_provider] : var.app_suite

  suite_app_titles = {
    microsoft = local.microsoft_app_titles
    google    = local.google_app_titles
    none      = {}
  }[local.effective_app_suite]

  app_installer_titles = merge(local.core_app_titles, local.suite_app_titles)

  # Dedupe: drop any common app whose catalog title is already deployed by
  # the core/suite set for this client (e.g. "Google Drive" for Google-suite
  # clients) — Jamf Pro rejects two App Installers for the same title.
  common_apps_effective = {
    for k, v in local.common_apps : k => v
    if !contains(values(local.app_installer_titles), v.title)
  }
}

resource "jamfpro_category" "apps" {
  name     = "Apps"
  priority = 9
}

# "Has <app>" smart groups for the common apps. Used for inventory visibility
# and, when common_apps_scope = "installed_only", as the deployment scope.
resource "jamfpro_smart_computer_group_v2" "has_common_app" {
  for_each = local.common_apps_effective

  name        = "Has ${each.value.title}"
  description = "Managed by Terraform. Macs with ${each.value.title} installed (auto-patched by App Installers)."

  criteria {
    name        = "Application Title"
    priority    = 0
    and_or      = "and"
    search_type = "has"
    value       = each.value.app
  }
}

# Common apps: automatic updates + supporting profiles.
#
# SCOPE NOTE: Jamf allows ONE App Installer deployment per title, so one
# deployment has to do both jobs (offer in Self Service + auto-patch).
# Scope per app:
#   - installed_only = false and common_apps_scope = "all" (default):
#     scoped to All Managed Clients. Nothing is pushed (deployment is
#     SELF_SERVICE), every user can install from Self Service, and any Mac
#     that has the app — however it got there — is auto-patched.
#   - installed_only = true (AI apps) or common_apps_scope = "installed_only":
#     scoped to the "Has <app>" smart group. Auto-patches existing installs;
#     Macs without the app don't see it in Self Service.
resource "jamfpro_app_installer" "common_apps" {
  for_each = local.common_apps_effective

  name            = each.value.title
  app_title_name  = each.value.title
  enabled         = true
  deployment_type = "SELF_SERVICE"
  update_behavior = "AUTOMATIC"
  category_id     = jamfpro_category.apps.id
  site_id         = "-1"
  smart_group_id  = (each.value.installed_only || var.common_apps_scope == "installed_only") ? jamfpro_smart_computer_group_v2.has_common_app[each.key].id : "1"

  install_predefined_config_profiles = true
  trigger_admin_notifications        = false

  self_service_settings {
    include_in_featured_category   = false
    include_in_compliance_category = false
    force_view_description         = false
    description                    = "${each.value.title} — installed on demand and kept up to date by IT. Managed by Terraform."

    categories {
      id       = jamfpro_category.apps.id
      featured = false
    }
  }

  # VERIFIED (live plan 2026-08-01): Jamf Pro auto-populates a
  # notification_settings block with defaults on every App Installer. Config
  # doesn't declare one, so without this every plan shows phantom drift on
  # all installers (and applying never clears it — the server re-adds it).
  lifecycle {
    ignore_changes = [notification_settings]
  }
}

# 1Password — only for clients who use it. Installed automatically on every
# Mac (it's the client's password manager, not an optional app) and kept
# up to date. Catalog title "1Password 8" VERIFIED June 2026.
resource "jamfpro_app_installer" "onepassword" {
  count = var.is_1password_customer ? 1 : 0

  name            = "1Password 8"
  app_title_name  = "1Password 8"
  enabled         = true
  deployment_type = "INSTALL_AUTOMATICALLY"
  update_behavior = "AUTOMATIC"
  category_id     = jamfpro_category.apps.id
  site_id         = "-1"
  smart_group_id  = "1" # All Managed Clients

  install_predefined_config_profiles = true
  trigger_admin_notifications        = false

  # Server auto-populates notification_settings — see common_apps note.
  lifecycle {
    ignore_changes = [notification_settings]
  }
}

resource "jamfpro_app_installer" "self_service" {
  for_each = local.app_installer_titles

  name            = each.value
  app_title_name  = each.value
  enabled         = true
  deployment_type = "SELF_SERVICE"
  update_behavior = "AUTOMATIC"
  category_id     = jamfpro_category.apps.id
  site_id         = "-1"
  smart_group_id  = "1" # built-in "All Managed Clients"

  install_predefined_config_profiles = true
  trigger_admin_notifications        = false

  self_service_settings {
    include_in_featured_category   = false
    include_in_compliance_category = false
    force_view_description         = false
    description                    = "${each.value} — installed and kept up to date by IT. Managed by Terraform."

    categories {
      id       = jamfpro_category.apps.id
      featured = false
    }
  }

  # Server auto-populates notification_settings — see common_apps note.
  lifecycle {
    ignore_changes = [notification_settings]
  }
}
