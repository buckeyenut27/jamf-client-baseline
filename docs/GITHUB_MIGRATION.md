# GitHub Migration Checklist — ✅ COMPLETED (August 2026)

> **Status:** this migration happened — the repo you are reading is the
> result. The checklist is preserved as the record of the sanitization
> process: every blocking item below was executed (secrets and state
> excluded, client folders stripped, history re-initialized cleanly,
> identifiers scrubbed) before the first push.

The repo currently assumes a PRIVATE OneDrive-synced folder where secrets
and state ARE the backup. Publishing to GitHub inverts that assumption.
Complete EVERY item below before the first push — a single missed tfvars
leaks client API credentials, Protect secrets, deploy codes, and the
msp_admin password.

## 1. Secrets out of the tree (BLOCKING)

- [ ] Flip `.gitignore`: uncomment the `**/*.tfstate`, `**/*.tfstate.backup`,
      and `**/terraform.tfvars` lines (marked in the file today).
- [ ] Add `clients/*/` to `.gitignore` EXCEPT `clients/_TEMPLATE/` — client
      folders contain tfvars (secrets), state (secrets in state!), and
      `.rollout-plan.log` files. Only the template belongs in git.
- [ ] Decide where client folders live going forward: stay in OneDrive
      outside the git tree (simplest), or move state to a remote backend
      (Azure Storage / Terraform Cloud) — required anyway before two techs
      run rollouts concurrently.
- [ ] `packages/` — vendor pkgs (44–80MB) don't belong in git. Ignore the
      folder, keep `packages/README.md`.
- [ ] Run a secret scanner over the FULL history before pushing anywhere
      (`trufflehog git file://.` or `gitleaks detect`). If the repo was ever
      committed with secrets, re-init history rather than scrub.
- [ ] Rotate anything that ever touched a machine you don't control.

## 2. Repo hygiene

- [ ] Private repo first; public only after a deliberate review (the
      Huntress account key pattern, client names, and tenant URLs must never
      appear in committed files — check comments and examples too).
- [ ] Add `LICENSE` decision (proprietary notice if staying closed).
- [ ] Keep `clients/_TEMPLATE/.terraform.lock.hcl` committed — that's the
      version pin.
- [ ] Delete dead files: `scripts/ea/bootstrap_token.sh` (superseded by the
      native criterion), any `*.mobileconfig` staged at repo root.

## 3. CI (nice-to-have, cheap)

- [ ] `terraform fmt -check -recursive`
- [ ] `terraform validate` against `clients/_TEMPLATE` with dummy vars
- [ ] `bash -n` over `*.sh` and the module `scripts/` tree
- [ ] Optional: tflint, checkov.

## 4. Docs expectations for external eyes

- [ ] README stays the operator runbook; ARCHITECTURE.md the design;
      PROVIDER_NOTES.md the quirk catalog. Scrub any client-identifying
      examples (the pilot tenant) before going public.
- [ ] Add a SECURITY.md contact if public.

## 5. What does NOT change

- `-parallelism=1`, the platform.tf file gate, singleton ownership,
  `ignore_changes` patterns, and the import-don't-duplicate doctrine are
  all provider-behavior driven — GitHub hosting changes none of them.
