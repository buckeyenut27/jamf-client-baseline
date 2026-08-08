# This client's baseline deployment.
# All real resources live in modules/client-baseline — every client gets the
# same baseline. Per-client differences come only from terraform.tfvars.

module "baseline" {
  source = "../../modules/client-baseline"

  client_name = var.client_name

  # Jamf Protect
  enable_jamf_protect         = var.enable_jamf_protect
  jamf_protect_mode           = var.jamf_protect_mode
  deploy_jamf_protect_profile = var.deploy_jamf_protect_profile

  # NOTE: Platform features (Blueprints / passcode / CIS) are configured in
  # platform.tf — rename platform.tf.off to platform.tf to enable them.

  # Fleet hygiene
  client_checkin_frequency = var.client_checkin_frequency

  # Security baseline & enrollment
  enable_security_baseline = var.enable_security_baseline
  screen_lock_idle_minutes = var.screen_lock_idle_minutes
  enable_prestage          = var.enable_prestage
  ade_instance_id           = var.ade_instance_id
  msp_admin_username     = var.msp_admin_username
  msp_admin_password     = var.msp_admin_password
  support_email             = var.support_email

  # EDR (huntress | sentinelone | none)
  edr_provider              = var.edr_provider
  huntress_account_key      = var.huntress_account_key
  huntress_organization_key = var.huntress_organization_key
  sentinelone_site_token    = var.sentinelone_site_token
  sentinelone_package_path  = var.sentinelone_package_path
  huntress_package_path     = var.huntress_package_path

  # Self Service apps
  app_suite             = var.app_suite
  common_apps_scope     = var.common_apps_scope
  is_1password_customer = var.is_1password_customer

  # Splashtop
  enable_splashtop       = var.enable_splashtop
  splashtop_deploy_code  = var.splashtop_deploy_code
  splashtop_package_path = var.splashtop_package_path

  # Jamf Connect (entra | google)
  idp_provider                 = var.idp_provider
  jamf_connect_oidc_client_id  = var.jamf_connect_oidc_client_id
  jamf_connect_entra_tenant_id = var.jamf_connect_entra_tenant_id
  jamf_connect_redirect_uri    = var.jamf_connect_redirect_uri
  jamf_connect_license_b64     = var.jamf_connect_license_b64
  enable_jamf_connect_menubar  = var.enable_jamf_connect_menubar

  jamf_connect_deny_local              = var.jamf_connect_deny_local
  jamf_connect_excluded_local_accounts = var.jamf_connect_excluded_local_accounts
  jamf_connect_admin_group             = var.jamf_connect_admin_group
  jamf_connect_migrate                 = var.jamf_connect_migrate
  jamf_connect_help_url                = var.jamf_connect_help_url
  enable_platform_sso          = var.enable_platform_sso
  company_portal_package_path  = var.company_portal_package_path
}

output "summary" {
  value = module.baseline.summary
}

output "manual_steps_remaining" {
  value = module.baseline.manual_steps_remaining
}
