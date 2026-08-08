# packages/

Local installer packages, shared by all clients. Terraform uploads the ones a
client needs to that client's Jamf tenant (JCDS) during `terraform apply` —
no manual upload in the Jamf UI.

Put these here:

| File | Used for | Notes |
|---|---|---|
| `Sentinel-Release_macos_v<version>.pkg` | SentinelOne clients | Download from the S1 management console (Sentinels → Packages). Reference it in the client's tfvars: `sentinelone_package_path = "../../packages/<file>.pkg"` |
| `SplashtopStreamerDeploy.pkg` | Splashtop clients | Composer-built pkg containing the deploy DMG + `deploy_splashtop_streamer.sh` at `/private/tmp/SplashtopInstall/` (see the splashtop_install.sh header for build steps). Reference via `splashtop_package_path` |
| Huntress pkg (optional) | Offline fallback only | The Huntress policy self-downloads from huntress.io; only add a pkg here if you want a fallback copy in the tenant (`huntress_package_path`) |
| `CompanyPortal-Installer.pkg` | Entra clients with Platform SSO | Download the **current** version from https://go.microsoft.com/fwlink/?linkid=853070 — old versions break PSSO (Microsoft requires 5.2604.0+). Self-updates via Microsoft AutoUpdate after install. Reference via `company_portal_package_path` |

Notes:

- Paths in tfvars are relative to the client folder, so `../../packages/...`.
- Permissions: there is no Jamf-side permissions setting on uploads. root:wheel
  ownership inside a pkg is set when the pkg is BUILT (Composer → Owner "root",
  Group "wheel"), and Jamf installs all pkgs as root.
- Uploads are big — the package resources have a 90-minute create timeout.
  First apply for a client will take a while on slow uplinks.
- When you drop in a new S1 version, update `sentinelone_package_path` in each
  client's tfvars and re-apply; Terraform re-uploads automatically (content
  changes are detected via SHA-256).
