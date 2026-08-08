locals {
  # Built-in "All Managed Clients" smart group (ID 1 in fresh Jamf Pro
  # tenants — VERIFIED live on the pilot tenant 2026-08-01, same group the App
  # Installers target). All baseline configuration profiles scope to this
  # group per MSP standard, NOT to "all computers".
  all_managed_clients_group_id = 1

  edr_enabled = var.edr_provider != "none"

  edr_display_name = {
    huntress    = "Huntress"
    sentinelone = "SentinelOne"
    none        = ""
  }[var.edr_provider]

  # Application Title as it appears in Jamf Pro computer inventory.
  # ASSUMPTION: verify against a real enrolled Mac's inventory record after the
  # first install, and adjust if the smart group never empties out.
  edr_app_title = {
    huntress    = "Huntress.app"
    sentinelone = "SentinelOne Extensions.app"
    none        = ""
  }[var.edr_provider]

  idp_display_name = {
    entra  = "Microsoft Entra ID"
    google = "Google Workspace"
    none   = "None (no Jamf Connect)"
  }[var.idp_provider]

  jamf_connect_enabled = var.idp_provider != "none"

  # Local accounts excluded from DenyLocal and hidden from migration:
  # the MSP service admin (always) plus any per-client extras.
  jamf_connect_excluded_accounts = distinct(compact(concat(
    [var.msp_admin_username],
    var.jamf_connect_excluded_local_accounts,
  )))
}
