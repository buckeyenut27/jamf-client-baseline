# Provider Notes — verified quirks and the patterns that survive them

Every entry below was hit LIVE during tenant builds (dates noted) and is
compensated for in the module. If you change the module, do not undo these
patterns without re-testing against a real tenant. Classification per
MSP convention: VERIFIED = observed live; ASSUMPTION = inferred.

## deploymenttheory/jamfpro

**Configuration profiles: Jamf rewrites inner payload UUIDs on save.**
(VERIFIED 2026-08-01) Every `jamfpro_macos_configuration_profile_plist`
would show phantom payload drift on each plan, and the provider refuses
the resulting update ("UUID mismatch"). Pattern: `ignore_changes =
[payloads]` on every profile. Consequence: profile CONTENT changes only
reach tenants via `terraform apply -replace='<resource>'` — documented in
the README "Making changes later".

**App Installers: server auto-populates `notification_settings`.**
(VERIFIED 2026-08-01) Undeclared block returns from the API → perpetual
25-resource drift. Pattern: `ignore_changes = [notification_settings]` on
all three app-installer resources.

**App Installer catalog titles drift.** (VERIFIED 2026-08-01: "OpenAI
ChatGPT" became "OpenAI ChatGPT Classic".) Invalid titles fail at apply
with the full valid list in the error — fix the map in `apps.tf` and
re-apply. Titles in the map are verified against a live tenant catalog.

**Disk encryption: two normalization drifts.** (VERIFIED 2026-08-01)
Server returns an empty `institutional_recovery_key` block (ignored via
lifecycle) and drops the provider-defaulted `remediate_key_type` when no
remediation config is attached (ignored via
`payloads[0].disk_encryption[0].remediate_key_type`).

**Duplicate names = 400/409, not adoption.** (VERIFIED 2026-08-03 on both
a script and a policy.) Jamf rejects same-name creates. Doctrine:
`terraform import` the existing object; the next apply reshapes it.

**Smart-group criterion list lags EA creation.** (VERIFIED 2026-08-03:
"criterion not valid" seconds after the EA was created.) Pattern:
`depends_on` the EA resource and expect a re-apply to succeed on fresh
tenants if the race hits.

**Native inventory fields can collide with EA names.** (VERIFIED
2026-08-03) "Bootstrap Token Escrowed" is a NATIVE criterion — creating an
EA with that name errors with a misleading "smart group/advanced search
exists" message. Check for a native criterion before writing an EA.

**API privilege names are non-obvious.** (VERIFIED 2026-08-03) App
Installer privileges are named "Mac Applications"; check-in and inventory
settings need "Computer Check-In" / "Computer Inventory Collection"
privileges. `bootstrap-api-client.sh` selects by keyword from the tenant's
LIVE privilege catalog so renames self-heal; its keyword list is the
source of truth.

**Jamf Cloud load balancer.** Provider guidance: `jamfpro_load_balancer_lock
= true` in the provider block and `terraform apply -parallelism=1` always.

## Jamf-Concepts/jamfplatform

**`tenant_id` is REQUIRED by the released provider** (VERIFIED 2026-08-01)
even though repo docs said optional. From the Integrations space at
account.jamf.com.

**The provider AUTHENTICATES during plan with zero resources.** (VERIFIED
2026-08-01 — placeholder credentials fail with `invalid_client`.) This is
why Platform features are gated by the `platform.tf` / `platform.tf.off`
FILE, not variables. Do not move the provider block back into
providers.tf.

**Blueprints flat schema deprecated** (`software_update`/`passcode_policy`
→ `component_blocks`, removal on/after 2026-10-22). Migration TODO with
date lives at the top of `modules/client-platform/blueprints.tf`.

**cbengine `sources` attribute is read-only in the released provider**
(VERIFIED 2026-08-01) despite main-branch docs — derived from
`source_baseline_id`. Do not set it.

## Jamf-Concepts/jamfprotect

**Authenticates at plan; API client role needs FULL read/write.**
(VERIFIED 2026-08-01: read-only-ish roles fail on `createActionConfigs` /
`createTelemetryV2`.)

**Analytic sets list API can return EMPTY while the console shows a
default set.** (VERIFIED 2026-08-03 on a fresh tenant.) Pattern in
`protect.tf`: prefer an API-visible managed/"default"-named set; when the
API sees none, CREATE "MSP Baseline Analytics" from every Jamf-managed
analytic. The lookup EXCLUDES our own set's name — without that exclusion
the created set satisfies the search and Terraform destroys the set it
just attached (near-miss caught live 2026-08-03).

**Empty-set/null inconsistency bug.** (VERIFIED 2026-08-03) Setting
`analytic_sets = []` on a plan triggers "Provider produced inconsistent
result" (empty set comes back null). Never attach an empty set; a
precondition fails loudly instead.

**A plan with no analytic sets produces NO analytic alerts.** Operational,
not a bug — the reason the baseline guarantees an attached set.

**Exception sets work as documented** — including adopting a hand-made set
by name ("Huntress EDR Coexistence") so takeover tenants don't get
duplicates. Terraform owns the plan's `exception_sets` AND `analytic_sets`
lists: console-added sets detach on the next apply; add them in the module.

**Plan config profile generation is not trusted** (issues without the
Platform-level API) — `deploy_jamf_protect_profile` defaults false and the
profile ships from the Protect console. Revisit when the provider path is
proven.

## Cross-provider doctrine

- Vendor Team IDs used in profiles/exceptions: Huntress `7W6HQ9J9XA`,
  SentinelOne `4AYE5J54KN`, Splashtop `CPQQ3AW49Y`, Jamf `483DWKW443`.
- Never build exception/allow rules on CDHash — breaks on every vendor
  update. Team ID (or Team ID + Signing ID) only.
- Jamf script parameters: Jamf passes $1–$3 positionally; policy-supplied
  values arrive as $4+. Scripts must consume $4+ (getopts is unreachable
  from Jamf).
