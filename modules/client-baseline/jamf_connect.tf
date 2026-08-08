# Jamf Connect configuration profiles.
# The IdP (Entra ID vs Google Workspace) is selected by var.idp_provider —
# the same profile resources are used either way; only the payload differs.
#
# NOTE: These templates cover the core OIDC keys. Before first production use,
# open the generated profile in the Jamf Connect Configuration app
# (Jamf Connect DMG > Jamf Connect Configuration.app) and confirm it validates
# for your Jamf Connect version. The Jamf Connect app/pkg itself is deployed
# separately (recommended: Jamf Pro App Installers) — see the README.

resource "jamfpro_macos_configuration_profile_plist" "jamf_connect_login" {
  count = local.jamf_connect_enabled ? 1 : 0

  name                = "Jamf Connect Login - ${local.idp_display_name}"
  description         = "Managed by Terraform. Jamf Connect login window settings for ${local.idp_display_name}."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.identity.id)
  user_removable      = false
  payload_validate    = false # template-generated plist, not exported from Jamf Pro

  # MSP standard login window posture:
  #   - DenyLocal (default on): all logins go through the IdP; the hidden
  #     PreStage admin and any listed accounts are excluded. LocalFallback
  #     stays on as the IdP-outage escape hatch.
  #   - OIDCAdmin (optional): members of the named IdP group become local
  #     admins; everyone else is standard. Requires the groups claim on the
  #     IdP app registration. VERIFY with the Jamf Connect Configuration app.
  #   - Migrate (per-client): for takeover fleets with existing local
  #     accounts; links them to IdP identities at first login.
  #   - HelpURL: help button at the login window.
  payloads = templatefile("${path.module}/templates/jamf_connect_login.mobileconfig.tftpl", {
    idp_provider      = var.idp_provider
    client_id         = var.jamf_connect_oidc_client_id
    tenant_id         = var.jamf_connect_entra_tenant_id
    redirect_uri      = var.jamf_connect_redirect_uri
    deny_local        = var.jamf_connect_deny_local
    excluded_accounts = local.jamf_connect_excluded_accounts
    admin_group       = var.jamf_connect_admin_group
    migrate           = var.jamf_connect_migrate
    help_url          = var.jamf_connect_help_url
  })

  scope {
    all_computers      = false
    computer_group_ids = [local.all_managed_clients_group_id]
  }

  lifecycle {
    precondition {
      condition     = var.jamf_connect_oidc_client_id != ""
      error_message = "idp_provider is '${var.idp_provider}' but jamf_connect_oidc_client_id is empty. Provide the OIDC client ID, or set idp_provider = \"none\" if this client does not receive Jamf Connect."
    }
    precondition {
      condition     = var.idp_provider != "entra" || var.jamf_connect_entra_tenant_id != ""
      error_message = "idp_provider is 'entra' but jamf_connect_entra_tenant_id is empty."
    }

    # Jamf Pro rewrites inner payload UUIDs on save (VERIFIED live
    # 2026-08-01) — ignore payload drift. IMPORTANT: because of this, tfvars
    # changes that alter this profile (admin group, DenyLocal, HelpURL, etc.)
    # only reach the tenant via: terraform apply -replace=<this resource>.
    ignore_changes = [payloads]
  }
}

# License profile — only created when Jamf Connect is in use and a license is provided.
resource "jamfpro_macos_configuration_profile_plist" "jamf_connect_license" {
  count = local.jamf_connect_enabled && var.jamf_connect_license_b64 != "" ? 1 : 0

  name                = "Jamf Connect License"
  description         = "Managed by Terraform. Jamf Connect license file."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.identity.id)
  user_removable      = false
  payload_validate    = false

  payloads = templatefile("${path.module}/templates/jamf_connect_license.mobileconfig.tftpl", {
    license_b64 = var.jamf_connect_license_b64
  })

  scope {
    all_computers      = false
    computer_group_ids = [local.all_managed_clients_group_id]
  }

  # Jamf Pro rewrites inner payload UUIDs on save — see jamf_connect_login.
  # License renewals: terraform apply -replace=<this resource>.
  lifecycle {
    ignore_changes = [payloads]
  }
}

# Menu bar app profile — disabled by default until validated with the
# Jamf Connect Configuration app (see variable enable_jamf_connect_menubar).
resource "jamfpro_macos_configuration_profile_plist" "jamf_connect_menubar" {
  count = local.jamf_connect_enabled && var.enable_jamf_connect_menubar ? 1 : 0

  name                = "Jamf Connect Menu Bar - ${local.idp_display_name}"
  description         = "Managed by Terraform. Jamf Connect menu bar app settings for ${local.idp_display_name}."
  level               = "System"
  distribution_method = "Install Automatically"
  redeploy_on_update  = "Newly Assigned"
  category_id         = tonumber(jamfpro_category.identity.id)
  user_removable      = false
  payload_validate    = false

  payloads = templatefile("${path.module}/templates/jamf_connect_menubar.mobileconfig.tftpl", {
    idp_provider = var.idp_provider
    client_id    = var.jamf_connect_oidc_client_id
    tenant_id    = var.jamf_connect_entra_tenant_id
    redirect_uri = var.jamf_connect_redirect_uri
  })

  scope {
    all_computers      = false
    computer_group_ids = [local.all_managed_clients_group_id]
  }

  # Jamf Pro rewrites inner payload UUIDs on save — see jamf_connect_login.
  lifecycle {
    ignore_changes = [payloads]
  }
}
