# Jamf Client Baseline (Terraform)

> **About this repo:** a production multi-tenant Jamf Pro + Jamf Protect
> provisioning system, designed and built by **Jackson Pavelka**. It stamps a
> complete, opinionated device-management baseline into new Jamf tenants —
> EDR, remote support, identity (Jamf Connect / Platform SSO), App
> Installers, security posture, DDM readiness, compliance smart groups —
> from one settings file per tenant. Built for and proven in a managed
> multi-tenant Apple environment (client identifiers, credentials, state,
> and vendor installers are stripped from this copy; everything else is the
> working system, verified against a production tenant in August 2026).
>
> Highlights for reviewers: `docs/PROVIDER_NOTES.md` (dated, live-verified
> provider behavior and the engineering patterns that survive it),
> `docs/ARCHITECTURE.md` (design doctrine), `bootstrap-api-client.sh`
> (least-privilege API role automation), `apply-all.sh` (multi-tenant
> rollout with per-tenant approval).
>
> **Note:** this is the sanitized public copy of an internal working
> system. Internal operational seams (SharePoint runbook references, the
> OneDrive repo-home section) are left intact deliberately — they show how
> the system is actually operated.

**What this does:** stamps our standard configuration into a brand-new client's
Jamf Pro + Jamf Protect tenants in one command. You fill in one settings file,
run three commands, and Terraform creates:

| Area | What gets created |
|---|---|
| Jamf Protect | Baseline plan, telemetry, action configuration, the **Huntress EDR Coexistence exception set** (Team ID rule, auto-adopted if one already exists), a guaranteed-attached **analytic set** (tenant default, or "MSP Baseline Analytics" built from every Jamf-managed analytic when the API exposes none), and the **macOS 15+ tamper-prevention profile** (non-removable system extensions). The plan's own config profile is deployed **from the Protect console** for now (`deploy_jamf_protect_profile = false` — see manual steps) |
| EDR (pick one) | Huntress **or** SentinelOne: install script, "Not Installed" smart group, self-healing install policy, **and the matching prerequisite config profile** — Huntress's official system extension/PPPC/content filter profile, or SentinelOne's system extension/network filter/FDA/notifications/login items profile (Team ID 4AYE5J54KN). The S1 installer pkg is uploaded to the tenant's JCDS from the local `packages/` folder and attached to the policy automatically |
| Splashtop | Install script, smart group, self-healing install policy with the client's deploy code, plus a PPPC profile (Accessibility + Full Disk Access granted silently; Screen Recording made approvable by standard users — macOS forbids silent MDM approval of screen recording). The Composer-built deploy pkg is uploaded to JCDS from `packages/` and attached to the policy automatically |
| Jamf Connect | Login window profile for **Entra ID or Google Workspace** (your pick), optional license profile. MSP login posture baked in: **DenyLocal** (all logins via the IdP; hidden PreStage admin + listed accounts excluded; LocalFallback stays on for outages), optional **OIDCAdmin** group for IdP-managed admin rights (empty = everyone standard), per-client **Migrate** toggle for takeover fleets, and a **Help button** pointing at MSP's site. `idp_provider = "none"` skips Jamf Connect entirely (note: with `app_suite = "auto"` that also means no productivity suite — force one if needed) |
| Platform SSO (Entra) | MSP standard for Entra clients, alongside Jamf Connect: Extensible SSO profile (Microsoft-documented values, **Password** sync method, FileVault `AttemptAuthentication`), **Company Portal deployed as a package + policy per Jamf's official PSSO article** (NOT App Installers — PSSO requires a current version and early install timing; the app self-updates via Microsoft AutoUpdate afterward), PreStage PSSO fields set, plus a "Platform SSO Registration" EA and "Not Registered" smart group to chase users who skip the one-time registration prompt. Jamf Connect keeps the login window; PSSO owns app SSO, Entra device registration (Conditional Access), and password sync — the menu bar profile stays off so there's exactly one sync mechanism |
| Self Service apps | App Installers for Adobe Acrobat Reader, Microsoft Teams, Zoom, Google Chrome — plus the productivity suite matching the client's IdP: **Microsoft 365** (Word, Excel, PowerPoint, Outlook, OneNote, OneDrive) for Entra clients, **Google apps** (Google Drive for desktop) for Google Workspace clients (`app_suite = "auto"`, overridable). All Self Service, auto-updating, with supporting config profiles installed automatically |
| Common apps (auto-patch) | App Installers + "Has \<app\>" smart groups for Canva, Slack, VS Code, WhatsApp, RingCentral, Firefox, Edge, Notion, Dropbox, VLC (in Self Service for everyone) and the **AI apps** — Claude, ChatGPT, Microsoft 365 Copilot, Google Gemini, Cursor AI — which are **update-only**: scoped to their "Has \<app\>" smart group so existing installs auto-patch but users without them never see them in Self Service |
| 1Password (toggle) | `is_1password_customer = true` pushes 1Password to **all** Macs automatically and keeps it updated. `false` (default) = not deployed |
| Self Service+ | Tenant-wide settings: Self Service+ enabled as the default end-user app (the tenant-wide checkbox — no VPP requirement, classic Self Service auto-removed) and set to install automatically on all Macs |
| macOS update Blueprints | Two Jamf Blueprints targeting all computers: **Minor** — "Ignore major versions" checked, enforced **14 days** after release; **Major** — unchecked, enforced **30 days** after release. Both install at 23:45 local device time (DDM `softwareupdate.enforcement.specific`) |
| Extension attributes | MSP visibility pack, collected at every inventory: **Max Supported macOS Version** (SOFA feed — upgrade planning against the update Blueprints), Days Since Last Reboot, Battery Cycle Count + Condition, Local Admin Accounts, Gatekeeper Status, Time Machine Last Backup, Jamf Connect version — plus the agent version EA matching the client's stack (Huntress / SentinelOne / Splashtop) |
| Security baseline | FileVault enforced with the Individual recovery key **escrowed to Jamf**, self-healing via a "FileVault - Not Encrypted" smart group; screen lock profile (password required immediately, 15 min idle default); macOS firewall profile; "Stale - No Check-in 30+ Days" smart group; passcode policy Blueprint (min length 8 default — raising it forces password changes) |
| PreStage (zero-touch) | Default ADE PreStage per client: mandatory non-removable MDM, consumer setup panes skipped, Recovery Lock enabled (Jamf-managed random password), **no minimum OS at enrollment** (the update Blueprints bring devices current afterward), the hidden `msp_admin` service account, MSP support contact shown at enrollment. **Prerequisite:** link the client's ABM to Jamf Pro first (Settings → Automated Device Enrollment) |
| MSP service admin | Hidden local admin (`msp_admin`, per-client password) on **every** Mac for lockout protection and support work. Created at enrollment by the PreStage (that copy gets a Secure Token and can unlock FileVault) and self-healed by an Ongoing policy + "MSP Admin - Missing" smart group for takeover/pre-existing Macs — the policy also re-promotes and re-hides the account if tampered. Auto-excluded from Jamf Connect DenyLocal. Note: the policy-created copy has **no Secure Token** (normal for post-FileVault script creation); the escrowed Individual Recovery Key is the FileVault fallback |
| CIS Level 1 (report only) | Compliance Benchmark with **all** CIS L1 controls in **MONITOR** mode — compliance posture is reported per device, nothing is enforced or remediated. Enforcement is hardcoded off by MSP policy; switching a client to enforce later is a deliberate manual change (and replaces the benchmark — `enforcement_mode` is immutable) |
| Fleet hygiene | Tenant singletons owned by the automation: client check-in every 15 min (tunable), inventory collection with **hidden accounts on** (required for the msp_admin group), weekly forced recon policy, and compliance smart groups — macOS Upgrade Available (SOFA EA), Battery Service Recommended, Time Machine Not Configured, Stale 7-day early warning |
| DDM readiness | Checker/fixer pack for declarative management (where update enforcement lives): DDM Status EA + "DDM - Not Enabled" group with a daily self-healing `profiles renew` policy, and "Bootstrap Token - Not Escrowed" group on Jamf's native criterion (takeover Macs need manual escrow — see the macOS Device Takeover Runbook in SharePoint) |
| Housekeeping | Standard categories: Security, Remote Support, Identity & Login, Apps |

You do **not** need to know Terraform. Follow the steps in order.

**Documentation map:** this README is the technician runbook. The design
and doctrine live in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); every
live-verified provider quirk (and the pattern that survives it) is in
[docs/PROVIDER_NOTES.md](docs/PROVIDER_NOTES.md); the checklist to complete
IF the repo ever moves to GitHub is [docs/GITHUB_MIGRATION.md](docs/GITHUB_MIGRATION.md).

**Repo home: OneDrive** (MSP decision, Aug 2026). The whole folder lives
in the synced OneDrive directory — state and tfvars ARE the backup; nothing
extra to configure. Two rules: ONE technician per client at a time (OneDrive
cannot merge tfstate conflicts), and if sync churns on the thousands of
files in `clients/*/.terraform/`, it is safe to delete those folders and
`terraform init` again — the committed lock file makes re-init exact.

---

## Step 1 — One-time setup on your Mac (first use only)

1. Install Homebrew if you don't have it: https://brew.sh
2. In Terminal:
   ```
   brew install terraform
   terraform -version
   ```
   Any version 1.13 or newer is fine. Client tenants must run **Jamf Pro
   11.20 or later** (the jamfpro provider's minimum; Jamf Cloud tenants are
   always current, so this only matters for unusual setups).
3. Make sure this whole `jamf-client-baseline` folder is in our OneDrive-synced
   location. The per-client files Terraform creates here **are the backup** —
   there is no cloud Terraform backend, on purpose.

## Step 2 — Start the new client

In Terminal, from this folder:

```
./new-client.sh "Acme Corp"
```

This creates `clients/Acme-Corp/` with a `terraform.tfvars` file — that's the
only file you edit.

## Step 3 — Collect the values and fill in terraform.tfvars

**Easiest way:** double-click `onboarding-form.html` (repo root) — it opens in
your browser, shows a form with only the fields you need, validates as you go,
and generates the `terraform.tfvars` file for you. Download it into the
client's folder (replace the template copy) and skip to Step 4. Everything
stays on your computer; nothing is uploaded.

**Manual way:** open `clients/Acme-Corp/terraform.tfvars` in a text editor and
fill every `PLACEHOLDER`. Either way, here's where each value comes from:

### 3a. Jamf Pro API client
**Shortcut for sandbox/testing:** instead of an API client you can pick
"Admin username/password" in the form (`jamfpro_auth_method = "basic"`) and
use a **local** Jamf Pro admin account — SSO-backed admins cannot
authenticate to the API this way. MSP standard account name:
**`msp_terraform`** (create it as a local administrator in each tenant
where basic auth is used). Fastest for a test tenant; for real client
tenants stick with API clients (dedicated identity in audit logs, revocable
secret, Jamf's supported direction).

**Standard path — run the bootstrap script** (skips the GUI privilege
checkbox wall entirely). From the repo root, with any LOCAL Jamf Pro admin
login for the new tenant:

```
./bootstrap-api-client.sh https://CLIENT.jamfcloud.com ADMIN_USERNAME
```

It reads the tenant's live privilege catalog, auto-selects everything the
baseline needs (Categories, Smart Computer Groups, Scripts, Policies,
macOS Configuration Profiles, Packages/JCDS, Computer Extension Attributes,
PreStage, Disk Encryption, App Installers, Self Service), shows you the
list for approval, creates the role `MSP Terraform Baseline` + API
client `msp-terraform`, and prints the Client ID/Secret to paste into
the form. Store the secret in 1Password immediately — it is shown once.

<details><summary>Manual GUI fallback (script unavailable)</summary>

1. Settings (gear) → **API roles and clients** → **API Roles** → New.
   Name it `MSP Terraform Baseline`. Grant **Create / Read / Update /
   Delete** privileges for: Categories, Smart Computer Groups, Scripts,
   Policies, macOS Configuration Profiles, Computer Extension Attributes,
   App Installers, Packages (incl. JCDS upload), Computer PreStage
   Enrollments, Disk Encryption, and Read/Update on Self Service settings.
2. **API Clients** tab → New. Name `msp-terraform`, assign the role,
   **Enable** it, save, then **Generate client secret**.
3. Copy the **Client ID** and **Client Secret** into the tfvars file.
   The secret is shown **once** — if you lose it, generate a new one.

</details>

### 3b. Jamf Protect API client
In the **client's Jamf Protect** console: **Administrative → API Clients →
Create**. Copy the URL (looks like `https://client.protect.jamfcloud.com`),
Client ID, and password into the tfvars file. Also shown once.

### 3c. Jamf Platform API client (for the software update Blueprints)
Blueprints run on the Jamf Platform API, which uses **Jamf Account**
credentials — this is a third, separate credential set:

1. Sign in at **account.jamf.com** with the account tied to the client's
   tenant, and create an API client with Blueprints and Device Group
   Inventory access (follow Jamf's "Getting started with Platform API" guide
   at developer.jamf.com if the menu has moved).
2. Copy the Client ID and Client Secret into the tfvars file and set the
   regional gateway URL (`us`/`eu`/`apac`). The **tenant UUID is REQUIRED**
   whenever any Platform feature (Blueprints, passcode policy, CIS
   benchmark) is enabled — the released Terraform provider refuses to run
   with it blank (VERIFIED on live run 2026-08-01; older provider docs
   saying "optional" are wrong for the released version). Find it in the
   **Integrations space at account.jamf.com**, listed next to the tenant
   you scoped the API client to.
3. **The Platform on/off switch is a FILE, not a variable** (VERIFIED live
   2026-08-01: the provider authenticates during `terraform plan` even with
   every Platform toggle set false, so toggles alone cannot turn it off):
   - Platform features OFF (default): leave `platform.tf.off` alone.
   - Platform features ON: rename `platform.tf.off` → `platform.tf` in the
     client folder, fill all three `jamfplatform_*` credentials plus the
     tenant UUID in tfvars, then run `terraform init` before planning.
   Run `terraform init` again any time you rename this file in either
   direction.

### 3d. Jamf Connect identity provider — pick what the client uses
- **Entra ID** (`idp_provider = "entra"`): in the client's Entra admin center,
  use (or create) the Jamf Connect app registration. You need the
  **Application (client) ID** and **Directory (tenant) ID**, and the redirect
  URI `https://127.0.0.1/jamfconnect` registered on the app. Follow Jamf's
  current guide: search learn.jamf.com for "Jamf Connect Entra ID integration".

  > **Conditional Access check.** Jamf Connect's password verification uses
  > the ROPG flow (`OIDCROPGID`), which is non-interactive and **fails if a
  > Conditional Access policy requires MFA or device compliance for that
  > app** — logins look broken even with correct passwords. Verify the Jamf
  > Connect app registration is excluded from MFA-requiring CA policies (or
  > create a dedicated ROPG app registration), per Jamf's "Jamf Connect and
  > Microsoft Conditional Access" guide on learn.jamf.com. Microsoft is also
  > steadily deprecating ROPC platform-wide (no hard date yet) — one more
  > reason the baseline pairs Jamf Connect with Platform SSO, which owns
  > password sync going forward.
- **Google Workspace** (`idp_provider = "google"`): create the OAuth client
  per Jamf's "Jamf Connect Google integration" guide and use its **client ID**.

  > **VALIDATE THE EDITION FIRST.** Jamf Connect's login window (OIDC) works
  > on any Google Workspace edition, but **password sync requires Google's
  > Secure LDAP service**, which is only included in: Business Plus,
  > Enterprise Standard/Plus, Education Fundamentals/Standard/Plus, Frontline
  > Standard/Plus, Enterprise Essentials Plus, and Cloud Identity Premium.
  > **Business Starter and Business Standard do NOT have it** — on those
  > editions the login window works but local passwords will drift from
  > Google with no sync. Check the client's edition in admin.google.com
  > (Billing → Subscriptions) before deploying Jamf Connect; if they're on
  > Starter/Standard, either have them upgrade or set expectations that
  > password sync is unavailable.

### 3e. EDR — pick what the client uses
- **Huntress** (`edr_provider = "huntress"`): Account Key + the client's
  Organization Key from the Huntress portal.
  > Deployment follows Huntress's official Jamf Pro guide (support.huntress.io
  > article 41788352133267): the system extension/PPPC profile deploys first,
  > and the install policy fires on recurring check-in ONLY (never at
  > enrollment) and is scoped to Macs that have already received the profile.
  > That ordering is what makes the agent install silent — don't add an
  > enrollment trigger to the policy in the Jamf UI.
- **SentinelOne** (`edr_provider = "sentinelone"`): the client site's
  **Site Token** from the S1 management console, plus the **exact file name**
  of the S1 installer pkg you upload to Jamf Pro (goes in
  `sentinelone_package_name`).

### 3f. Splashtop
Deploy (stream) code from the Splashtop web console → Management → Deployment.

## Step 4 — Run it

```
cd clients/Acme-Corp
terraform init
terraform plan
```

`terraform plan` is a **dry run** — it changes nothing. Read the summary line
at the bottom (e.g. `Plan: 14 to add, 0 to change, 0 to destroy`). If it shows
errors, fix the tfvars value it points at and run `terraform plan` again.

When the plan looks right:

```
terraform apply -parallelism=1
```

Type `yes` when prompted. **Always use `-parallelism=1`** — Jamf Cloud's API
misbehaves with parallel writes (documented by the provider).

## Step 5 — Finish the manual steps

Terraform prints a `manual_steps_remaining` list when it finishes. In short:

1. **Deploy the Jamf Connect app** — Jamf Pro → Settings → App Installers
   (Jamf Connect is in the catalog). Terraform configures Jamf Connect; it
   doesn't install the app itself.
2. **SentinelOne only:** upload the client's S1 installer pkg to Jamf Pro,
   attach it to the "Install SentinelOne" policy with action **Cache**, and
   make sure `sentinelone_package_name` in tfvars matches the file name
   exactly.
3. **Splashtop only:** upload the Composer-built `Streamer.pkg` (containing
   the deploy DMG + `deploy_splashtop_streamer.sh` in
   `/private/tmp/SplashtopInstall/`) and attach it to the "Install Splashtop
   Streamer" policy. Details are in the header of
   `modules/client-baseline/scripts/splashtop_install.sh`.
4. **Huntress only:** nothing extra — Terraform deploys Huntress's official
   system extension / PPPC / content filter profile automatically (it's
   vendored at `modules/client-baseline/profiles/`; re-sync it if Huntress
   updates theirs on GitHub).
5. **Set the inventory display columns** (manual — Jamf stores these per
   Jamf Pro user account and offers no API for them, so Terraform cannot
   set them). While logged in as the MSP service/technician account:
   - **Computers → Search Inventory** → run a blank search → open the
     column/display settings and check exactly: **Computer Name, Serial
     Number, Username, Model, Last Check-in, Last Inventory Update**.
   - **Devices → Search Inventory** (mobile) → same steps with the iOS
     equivalents: **Display Name, Serial Number, Username, Model, Last
     Inventory Update** (iOS devices report inventory updates rather than
     a Mac-style check-in).
   Repeat once per Jamf Pro account that techs use in this tenant.
6. **Enroll a test Mac** and verify: Protect profile installed, EDR agent
   installed and the Mac drops out of the "Not Installed" smart group,
   Self Service shows the app catalog, Jamf Connect login window appears and
   signs in with the client's IdP.

## Making changes later

**Documentation rule:** any change to this repo updates its documentation
in the same sitting — feature table, form, tfvars example, provider notes,
manual steps. The mapping lives in `CLAUDE.md` at the repo root.

Edit the client's `terraform.tfvars` (or the shared module, for changes to
**all** clients), then from the client folder:

```
terraform plan          # review
terraform apply -parallelism=1
```

Terraform only touches what changed. If someone edited a Terraform-managed
object in the Jamf UI, `terraform plan` will show the drift and `apply` will
put it back — that's a feature.

**EXCEPTION — configuration profile CONTENT (VERIFIED live 2026-08-01):**
Jamf Pro rewrites the inner payload UUIDs of every configuration profile it
stores, so Terraform deliberately ignores payload drift on profiles (otherwise
every apply after the first would fail with "UUID mismatch"). Consequence:
editing a profile's content — the screen lock timeout, a Jamf Connect setting,
a PPPC change, a renewed Jamf Connect license — does NOT reach the tenant with
a normal apply. Push it by replacing that one profile:

```
terraform plan                       # copy the profile's full address from the output
terraform apply -parallelism=1 -replace='module.baseline.jamfpro_macos_configuration_profile_plist.screen_lock[0]'
```

Replacing a profile removes and re-installs it on devices at next check-in —
harmless for settings profiles. Name/description/scope changes still apply
normally; only the payload content needs `-replace`.

### Rolling a module change to EVERY client

Because every client folder consumes the same `modules/client-baseline`,
editing the module stages the change for all tenants automatically — each
tenant picks it up on its next apply. To fan it out in one sitting, use the
rollout runner at the repo root:

```
./apply-all.sh              # plan every client, report who has pending changes
./apply-all.sh apply        # same, then y/N per client — approved plans apply
./apply-all.sh plan Pilot    # limit to client folders matching a name
```

Rules of the road:

- The runner NEVER applies without a per-client yes, and it applies the
  exact saved plan you reviewed (`.rollout-plan.log` in each client folder
  has the details).
- Applies run `-parallelism=1` automatically.
- One tech at a time, same as always — local state means two people running
  rollouts simultaneously will corrupt state.
- A tenant that fails stops the apply phase so you can investigate before
  the change reaches more clients. Fix, then re-run — already-applied
  tenants will show "no changes" and be skipped naturally.
- Good hygiene for risky module changes: roll to ONE client first
  (`./apply-all.sh apply Pilot`), verify in that tenant, then run the full
  fleet.

---

## Troubleshooting

**Known first-apply behaviors on a FRESH tenant** (all seen on the
production pilot — none require fixing anything):

| Behavior | What to do |
|---|---|
| A smart group fails with "The criterion \<EA name\> is not valid" | Jamf's criterion list lags EA creation by seconds. Run `terraform apply -parallelism=1` again — the second pass succeeds. Everything already created stays created. |
| An App Installer fails with a long list of valid titles | Jamf renamed a catalog title. Find the closest match in the error's list, fix the title in `modules/client-baseline/apps.tf`, re-apply. |
| The apply sits on a package for many minutes | Normal — the 44–80MB pkgs upload to JCDS with 90-minute timeouts. Don't interrupt. |
| **Takeover tenant:** "duplicate name" on a script or policy | A hand-made object with that name already exists. Don't rename — `terraform import '<resource address>' <id>` (ID from the object's URL in the Jamf UI), then re-apply so Terraform reshapes it to the managed spec. |

| Symptom | Fix |
|---|---|
| `401` / `invalid_client` during plan | Jamf Pro or Protect client ID/secret wrong, or the API client isn't enabled. Re-check 3a/3b. |
| `403` / privilege errors | The Jamf Pro API **role** is missing a privilege. Add it to the role (3a) and re-run. |
| Resources "not found" right after apply | Jamf Cloud load-balancer lag. Wait 60s, run `terraform plan` again. The provider's sticky-session lock is already on. |
| Plan wants to recreate the Jamf Protect profile every run | Expected to be suppressed — it's configured with `ignore_changes`. If you still see it, mention it when updating the module. |
| `Error: Invalid value for variable` | A toggle has a typo — `edr_provider` must be exactly `huntress`/`sentinelone`/`none`, `idp_provider` exactly `entra`/`google`. |
| Lost the tfvars or state file | They live only in the client folder (OneDrive). Restore from OneDrive version history. |
| Mac never leaves the "Not Installed" smart group | The app name in inventory doesn't match the group criteria. Check the Mac's inventory → Applications, and update the value in `modules/client-baseline/locals.tf`. |
| Apply fails looking up an app title | Catalog spelling changed. Check Jamf Pro → Mac Apps → App Installers for the exact title and fix the map in `modules/client-baseline/apps.tf`. |
| "Install SentinelOne" policy fails: package not found | The pkg isn't attached to the policy as **Cache**, or `sentinelone_package_name` doesn't match the uploaded file name exactly. |
| Splashtop policy fails: assets not present | The Composer-built `Streamer.pkg` isn't attached to the policy, or was built without both the DMG and deploy script — see the script header for rebuild steps. |
| `Error: ... name already exists` on apply | The tenant already has an object with the same name (e.g. a hand-made "Security" category). Either delete/rename it in the Jamf UI, or adopt it with `terraform import` so Terraform owns it from now on. Tenant-wide *settings* don't hit this — they're overwritten by design. |

## Rules

- **Terraform owns tenant-wide settings.** Self Service / Self Service+
  settings (and any future tenant-level settings added to the baseline) are
  enforced by this automation: if the tenant already had different values,
  the first apply **overrides** them, and manual UI changes are **reverted**
  on the next apply. This is intentional — the baseline wins. Enforcement
  happens at apply time, so run `terraform plan` (and `apply` if it shows
  drift) in each client folder periodically — monthly, or whenever something
  in a tenant looks off.
- **Never** edit Terraform-managed objects in the Jamf web UI (they're labeled
  "Managed by Terraform"). Change tfvars/module instead — the next apply will
  revert UI edits anyway.
- **Never** delete `terraform.tfstate` from a client folder. It's Terraform's
  memory of what it built.
- One client = one folder = one state. Don't copy state files between clients.
- `terraform destroy` removes everything the baseline created for that client.
  Don't run it casually.

## What's verified vs. what needs your eyes

- **VERIFIED** — provider names/auth and every Terraform resource schema in
  this repo were checked against the official provider docs
  (`deploymenttheory/jamfpro`, `Jamf-Concepts/jamfprotect`,
  `Jamf-Concepts/jamfplatform`) in June 2026, and the design was reviewed
  against Jamf Pro 11.29's deprecations list: no baseline feature is on the
  deprecation path (updates are DDM/Blueprints, Self Service+ is the
  default, smart groups use the v2 API, policies don't use the deprecated
  offline mode). The PreStage PSSO fields align with Jamf's Simplified
  Setup for Platform SSO (Unattended workflow, Jamf Pro 11.20+).
- **ASSUMPTION (check once)** — inventory app names used by the smart groups
  (`Huntress.app`, `SentinelOne Extensions.app`, `Splashtop Streamer.app`) —
  verify on the first enrolled Mac; adjust `locals.tf` if needed.
- **VERIFIED** — every App Installer title in
  `modules/client-baseline/apps.tf` was checked against Jamf's official
  App Installers Software Titles list (learn.jamf.com, June 2026). If Jamf
  renames one later, apply fails with a clear lookup error; fix the map.
- **ASSUMPTION (check once)** — the inventory app names (`.app` values) used
  by the "Has \<app\>" smart groups. If a "Has" group stays empty on a Mac
  that clearly has the app, check the Mac's inventory → Applications and fix
  the name in `apps.tf`.
- **ASSUMPTION (check once)** — Jamf Connect profile keys cover the standard
  OIDC set plus DenyLocal/Migrate/HelpURL/OIDCAdmin; validate the generated
  profile with the **Jamf Connect Configuration app** before the first
  production client (OIDCAdmin especially — it also needs the groups claim
  on the IdP app registration), and before enabling the menu bar profile.
  On the test Mac, confirm the excluded PreStage admin can still log in
  locally with DenyLocal active before deploying widely.
- **Install scripts** — the three scripts in `modules/client-baseline/scripts/`
  are MSP's production scripts (Huntress's official vendor script wired to
  Jamf parameters 4/5; MSP's SentinelOne and Splashtop deploy scripts).
  They expect their package prerequisites — see Step 5 items 2–4.
- **Prerequisite profiles** — Huntress profile is the vendor's verbatim file
  (VERIFIED). SentinelOne values (Team ID 4AYE5J54KN, the four FDA daemons and
  their code requirements, network extension) match S1's documented MDM
  configuration; Splashtop values (Team ID CPQQ3AW49Y, bundle
  com.splashtop.Splashtop-Streamer) match the community PPPC profile.
  ASSUMPTION (check once): verify on the first test Mac that the S1 network
  filter and FDA entries show approved with no user prompts, and that
  Splashtop's Accessibility/FDA toggles are pre-enabled.

## Optional: capture an existing "golden" tenant

If you've hand-built a perfect tenant and want Terraform code generated from
it, Jamf's **jamformer** tool does exactly that (read-only):
https://concepts.jamf.com/en/concepts/jamformer/ — useful for expanding this
baseline with profiles/policies you already trust.

---

*the MSP — example.com*
