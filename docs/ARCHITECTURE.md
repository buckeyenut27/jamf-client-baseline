# Architecture — MSP Jamf Client Baseline

How this repo turns a blank Jamf Pro + Jamf Protect tenant into a fully
configured MSP client, and why it is shaped the way it is. Read this
before changing the module. Operational how-to lives in [README.md](../README.md);
provider landmines live in [PROVIDER_NOTES.md](PROVIDER_NOTES.md).

## The problem

MSP onboards each client into its own isolated Jamf Pro tenant (plus a
Jamf Protect tenant and optionally the Jamf Platform API). Hand-building
tenants doesn't scale and drifts immediately. This repo makes the tenant
build repeatable: one shared module, one tfvars file per client, one
`terraform apply` per tenant.

## Repo layout

```
jamf-client-baseline/
├── README.md                  ← technician runbook (start here to USE the repo)
├── onboarding-form.html       ← GUI that generates a client terraform.tfvars
├── bootstrap-api-client.sh    ← creates the scoped Jamf Pro API role + client per tenant
├── apply-all.sh               ← multi-tenant rollout runner (plan all / apply per-client)
├── docs/                      ← this documentation
├── packages/                  ← local pkgs uploaded to each tenant's JCDS (not in git once public)
├── modules/
│   ├── client-baseline/       ← THE baseline: everything every client gets
│   └── client-platform/       ← OPTIONAL: Jamf Platform features (Blueprints/passcode/CIS)
└── clients/
    ├── _TEMPLATE/             ← copy to start a client; includes platform.tf.off
    └── <Client>/              ← per-client: tfvars (secrets), local tfstate, lock file
```

## Core design decisions

### One shared module, thin client folders

Every client folder consumes `modules/client-baseline`. Per-client
difference lives ONLY in `terraform.tfvars`. Editing the module stages the
change for every tenant; `apply-all.sh` fans it out with per-client
approval. There is no per-client Terraform code beyond pass-throughs.

### Local state, folder-per-client, OneDrive as backup

State is a local `terraform.tfstate` in each client folder. The repo is
designed to live in a OneDrive-synced folder, so state and tfvars ARE the
backup. There is no state locking — the operating rule is ONE technician
per client at a time. (Revisit with a remote backend before multi-tech
concurrency; see [GITHUB_MIGRATION.md](GITHUB_MIGRATION.md).)

### Optional stacks are FILES, not variables

The `jamfplatform` provider authenticates during `terraform plan` even
when every one of its resources is `count = 0` (VERIFIED live 2026-08-01).
A variable can therefore never turn a provider "off". The reliable
off-switch is file presence: `clients/<X>/platform.tf.off` holds the
provider block and module call; rename to `platform.tf` (plus real
credentials) to enable. `modules/client-platform` exists as a separate
module for exactly this reason.

### Tenant-wide singletons: the automation wins

Self Service settings, Self Service+, client check-in, and inventory
collection are singletons the module owns outright. No `ignore_changes` —
if someone flips them in the UI, the next apply flips them back. This is
deliberate MSP policy.

### Self-healing install pattern

Every agent install (EDR, Splashtop, Company Portal, msp_admin) uses
the same three-piece pattern: a smart group of Macs MISSING the thing, an
Ongoing policy scoped to that group triggered at check-in, and a `recon`
maintenance payload so remediated Macs leave the group immediately. Failed
installs retry automatically; new Macs self-heal with zero touch.

### Profile-first EDR ordering

Per Huntress's official Jamf guide, the system-extension/PPPC profile must
land before the install script runs (silent install). Enforced two ways:
the install policy has NO enrollment trigger (check-in only), and the
scoping smart group additionally requires the EDR profile to be present on
the Mac.

### Import, don't duplicate

Takeover tenants contain hand-made objects (scripts, policies, exception
sets). Jamf rejects duplicate names — the doctrine is `terraform import`
the existing object and let the next apply reshape it to the managed spec.
The Protect exception-set logic goes further and auto-adopts an existing
set by name.

### DDM readiness is part of the baseline

Update enforcement is DDM (Blueprints). The baseline therefore ships the
checkers (DDM Status EA, native Bootstrap Token criterion, smart groups)
and the fixer (`profiles renew -type enrollment` policy). Takeover Macs
need manual Bootstrap Token escrow — see the macOS Device Takeover Runbook
in the MSP Operations SharePoint.

## Providers and credentials (per tenant)

| Provider | Auth | Created by | Notes |
|---|---|---|---|
| deploymenttheory/jamfpro | OAuth2 API client (or basic) | `bootstrap-api-client.sh` | scoped role from live privilege catalog; `-parallelism=1` + load-balancer lock required |
| Jamf-Concepts/jamfprotect | API client | Protect console (manual) | role needs FULL read/write; authenticates at plan time |
| Jamf-Concepts/jamfplatform | API client + tenant UUID | account.jamf.com (manual) | only when `platform.tf` enabled; authenticates at plan time |

Provider versions are pinned by the committed `.terraform.lock.hcl` in
`clients/_TEMPLATE/` (proven: jamfpro v0.41.0, jamfprotect v0.10.0,
jamfplatform v0.25.2).

## Client-facing knobs (tfvars)

The onboarding form generates every value. The big switches: `edr_provider`
(huntress / sentinelone / none), `idp_provider` (entra / google / none —
drives Jamf Connect and, for entra, Platform SSO), `app_suite` (auto
follows IdP), `common_apps_scope`, `is_1password_customer`,
`enable_splashtop`, `enable_security_baseline`, `enable_prestage`,
`enable_jamf_protect` (+ `deploy_jamf_protect_profile`, default false —
profile ships from the Protect console for now), and the platform.tf file
switch. `msp_admin_password` is required per client.

## Documentation contract

No repo change is complete until the documentation matches it — same
session, not later. The full mapping of change-type → doc-to-update lives
in [CLAUDE.md](../CLAUDE.md) at the repo root (standing rule, 2026-08-03).
The short version: deployed-stuff changes update the README table, variable
changes update template + form + example, provider surprises go in
PROVIDER_NOTES.md with a date, and anything manual lands in the
`manual_steps_remaining` output.

## What stays manual (by constraint, not choice)

Inventory display columns (no API), Jamf Connect app deployment via App
Installers UI, the Protect plan's configuration profile (provider issues
without the Platform-level API), Huntress-side allow-listing of Jamf
Protect (Huntress has no exclusions API), Bootstrap Token escrow on
takeover Macs (needs a secure-token admin login), and ABM linking before
PreStage. All surfaced in the `manual_steps_remaining` output.
