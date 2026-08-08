# Client Onboarding Checklist — Jamf Baseline

Client: ______________________  Technician: ______________________  Date: ____________

## Before you start — collect these

- [ ] APNs push certificate created in the tenant (and renewal date calendared — annual!)
- [ ] Apple Business Manager linked to Jamf Pro (ADE token uploaded) — required for the PreStage
- [ ] ABM/VPP token renewal dates calendared

- [ ] Jamf Pro URL: `https://__________.jamfcloud.com`
- [ ] Jamf Pro API Client ID + Secret created (role: Terraform Baseline) — README 3a
- [ ] Jamf Protect URL: `https://__________.protect.jamfcloud.com`
- [ ] Jamf Protect API Client ID + password created — README 3b
- [ ] Jamf Platform API client (Jamf Account) + tenant UUID + region — README 3c (or blueprints set to false)
- [ ] EDR for this client:  ☐ Huntress  ☐ SentinelOne
  - [ ] Huntress: Account Key + Organization Key, **or**
  - [ ] SentinelOne: Site Token + installer pkg from S1 console (note exact file name for `sentinelone_package_name`)
- [ ] Splashtop deploy code
- [ ] IdP for this client:  ☐ Entra ID  ☐ Google Workspace
  - [ ] Entra: Application (client) ID + Directory (tenant) ID, **or**
  - [ ] **Entra only:** Jamf Connect app registration excluded from MFA-requiring Conditional Access policies (ROPG password verification fails otherwise) — README 3d
  - [ ] Google: OAuth client ID
  - [ ] **Google only:** Workspace edition supports Secure LDAP (Business Plus / Enterprise / Education / Frontline / Cloud Identity Premium — NOT Business Starter or Standard). Check admin.google.com → Billing → Subscriptions. Without it, Jamf Connect password sync is unavailable — README 3d
- [ ] Jamf Connect license file (optional)

## Run

- [ ] `./new-client.sh "Client Name"`
- [ ] Fill `terraform.tfvars` — easiest via `onboarding-form.html` (generates and downloads the file); otherwise fill every PLACEHOLDER by hand
- [ ] `cd clients/<Client>` then `terraform init`
- [ ] `terraform plan` — no errors, additions count looks right (~10–16)
- [ ] `terraform apply -parallelism=1` — completed without errors

- [ ] App suite confirmed (`app_suite = "auto"` gives Entra → Microsoft 365, Google → Google Drive)
- [ ] 1Password customer?  ☐ Yes (`is_1password_customer = true`)  ☐ No

## After apply

- [ ] Inventory display columns set (manual, per Jamf Pro account — no API):
  - Computers: Computer Name · Serial Number · Username · Model · Last Check-in · Last Inventory Update
  - Devices (iOS): Display Name · Serial Number · Username · Model · Last Inventory Update

- [ ] Jamf Connect app deployed via App Installers
- [ ] SentinelOne only: pkg uploaded + attached to "Install SentinelOne" policy (action: Cache)
- [ ] Splashtop only: Composer-built Streamer.pkg attached to "Install Splashtop Streamer" policy
- [ ] Huntress only: "Huntress - System Extension, PPPC & Content Filter" profile shows Installed on test Mac (deployed by Terraform)
- [ ] SentinelOne only: "SentinelOne - System Extension, PPPC & Network Filter" profile Installed; agent shows no permission prompts; `sentinelctl status` healthy
- [ ] Splashtop only: "Splashtop Streamer - PPPC" profile Installed; Accessibility + Full Disk Access pre-granted; user can enable Screen Recording without admin rights
- [ ] Self Service+ installed automatically on test Mac (Settings > Self Service+ shows enabled)
- [ ] Both "macOS Software Updates" Blueprints show Deployed (minor 14d / major 30d, install 23:45)
- [ ] "CIS Level 1 - Report Only" benchmark shows SYNCED and mode = Monitor (NOT enforce)
- [ ] Self Service shows core apps + correct suite
- [ ] Test Mac enrolled
- [ ] Jamf Protect profile shows Installed on test Mac
- [ ] EDR agent installed; Mac left the "Not Installed" smart group after recon
- [ ] Splashtop Streamer installed and connects
- [ ] Jamf Connect login window appears and signs in with client IdP
- [ ] msp_admin present on test Mac (hidden, admin); Mac left "MSP Admin - Missing" group; account NOT visible at login window user list
- [ ] DenyLocal verified: local accounts blocked at login window EXCEPT msp_admin (test msp_admin can still log in before wide deployment)
- [ ] If admin group set: member of the group gets admin, non-member standard (needs groups claim on the IdP app)
- [ ] Takeover clients with Migrate on: existing local account links to IdP identity at first login (no duplicate account created)
- [ ] Entra + PSSO: current CompanyPortal-Installer.pkg in packages/ (from go.microsoft.com/fwlink/?linkid=853070) and path set in tfvars
- [ ] Entra + PSSO (first-run validation): Company Portal installed by policy; "Registration Required" prompt appears once; registration completes; NO duplicate password-sync prompts from Jamf Connect; Mac leaves "Platform SSO - Not Registered" group after recon; device appears registered in Entra
- [ ] Extension attributes populated after first recon (check "Max Supported macOS Version" and the agent version EAs on the test Mac)
- [ ] Client folder synced to OneDrive (tfvars + tfstate present)

Notes / deviations:

____________________________________________________________________________

____________________________________________________________________________
