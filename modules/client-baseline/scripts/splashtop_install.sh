#!/bin/bash
# ============================================================================
# the MSP — CONFIDENTIAL
# Jamf Pro Script: Splashtop Streamer (standalone) Deploy for macOS
# Companion to: MSP_Atera_to_Splashtop_macOS_Migration_Runbook_v1.0
#
# Purpose: Mount the cached Splashtop Streamer DEPLOY DMG and run the bundled
#          deploy_splashtop_streamer.sh with the MSP deployment code.
#
# Assumptions:
#   - The Jamf policy has already cached the DMG to /Library/Application Support/JAMF/Waiting Room/
#     OR has placed it at /private/tmp/ via the policy's Package payload.
#   - The Atera uninstaller script (uninstall_atera_macos.sh) ran first.
#
# Replace DEPLOY_CODE below with the 12-digit Splashtop deployment code from
# https://my.splashtop.com -> Management -> Deployment.
# DO NOT commit a populated DEPLOY_CODE to git or paste it in tickets.
#
# Exit codes:
#   0 = success
#   1 = failure (DMG not found, mount failed, deploy script error)
# ============================================================================

set -u

LOG_TAG="[msp-splashtop-deploy]"
log() { echo "${LOG_TAG} $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# ---- CONFIGURATION --------------------------------------------------------
DEPLOY_CODE="REPLACE_WITH_12_DIGIT_CODE"          # From Splashtop console
# Optional Jamf script parameter override: $4 can carry the deploy code
# so the value lives only in Jamf and not in the script body.
if [ -n "${4:-}" ]; then
  DEPLOY_CODE="$4"
fi

if [ "${DEPLOY_CODE}" = "REPLACE_WITH_12_DIGIT_CODE" ] || [ -z "${DEPLOY_CODE}" ]; then
  log "FAIL: DEPLOY_CODE not set. Pass via Jamf script parameter \$4 or edit this script."
  exit 1
fi

# ==========================================================================
# Splashtop's official Jamf Pro deployment pattern (KB 360042998132):
#   - Composer builds Streamer.pkg from a source folder at /private/tmp/<Name>/
#     containing two assets:
#       * Splashtop_Streamer_Mac_DEPLOY_INSTALLER_v*.dmg
#       * deploy_splashtop_streamer.sh
#   - After the .pkg installs, those assets live at /private/tmp/<Name>/.
#   - This script (or Jamf's Files-and-Processes Execute Command, per the
#     vendor doc) then runs the deploy script with the tenant's $4 code.
#
# MSP standardizes the source folder name as "SplashtopInstall" so the
# assets land at /private/tmp/SplashtopInstall/. If a different name is used
# at packaging time, the find below still locates the files anywhere under
# /private/tmp/.
# ==========================================================================

PRIMARY_DIR="/private/tmp/SplashtopInstall"
DEPLOY_SCRIPT="${PRIMARY_DIR}/deploy_splashtop_streamer.sh"
DMG=$(/usr/bin/find "${PRIMARY_DIR}" -maxdepth 1 \
  -name "Splashtop_Streamer_Mac_DEPLOY_INSTALLER*.dmg" -print -quit 2>/dev/null)

# Strict: only look at /private/tmp/SplashtopInstall/. If the assets aren't
# there, the Streamer.pkg install didn't complete cleanly (or wasn't the
# correct .pkg). Don't fall back to stale /private/tmp/* from prior runs —
# that produces confusing errors like "Resource busy" on half-mounted DMGs.
if [ ! -f "${DEPLOY_SCRIPT}" ] || [ -z "${DMG}" ]; then
  log "FAIL: Required assets not present at ${PRIMARY_DIR}."
  log "  Expected: ${PRIMARY_DIR}/deploy_splashtop_streamer.sh and ${PRIMARY_DIR}/Splashtop_Streamer_Mac_DEPLOY_INSTALLER_v*.dmg"
  log "  Got:      deploy_script_present=$([ -f "${DEPLOY_SCRIPT}" ] && echo yes || echo no)  dmg='${DMG}'"
  log ""
  log "  This usually means one of:"
  log "    A. The Streamer.pkg install failed earlier in this policy run"
  log "       (look upstream for 'package could not be verified' — the JCDS-hosted .pkg in this"
  log "        tenant is corrupt or the wrong build; delete + re-upload Streamer.pkg in the Jamf UI)."
  log "    B. The Streamer.pkg uploaded to this tenant was built from a Composer source folder"
  log "       that didn't include both files. Rebuild per runbook Section 4.2:"
  log "         mkdir -p /private/tmp/SplashtopInstall"
  log "         cp <DMG> /private/tmp/SplashtopInstall/"
  log "         cp deploy_splashtop_streamer.sh /private/tmp/SplashtopInstall/  (from Splashtop KB 212725183)"
  log "         chmod +x /private/tmp/SplashtopInstall/deploy_splashtop_streamer.sh"
  log "         Composer: drag /private/tmp/SplashtopInstall -> Build as PKG"
  exit 1
fi
log "Using deploy script: ${DEPLOY_SCRIPT}"
log "Using installer DMG: ${DMG}"

# ---- Run the silent deploy ------------------------------------------------
# Splashtop documented flags (support article 212725183):
#   -i <dmg>   inner installer image
#   -d <code>  12-digit deployment code (Jamf parameter $4)
#   -w 0       no confirmation prompt
#   -s 0       hide Streamer window after install
#   -v 0       skip Splashtop Sound driver
chmod +x "${DEPLOY_SCRIPT}" 2>/dev/null || true
log "Running: ${DEPLOY_SCRIPT} -i ${DMG} -d <REDACTED> -w 0 -s 0 -v 0"
/bin/bash "${DEPLOY_SCRIPT}" -i "${DMG}" -d "${DEPLOY_CODE}" -w 0 -s 0 -v 0
RC=$?

# ---- Detach fallback mount if used ---------------------------------------
# MSP FIX (2026-06-11): MOUNT_DIR is never set in this script version; with
# `set -u` the unguarded expansion aborted the script AFTER a successful deploy,
# making every policy run report failure. Guard with a default.
if [ -n "${MOUNT_DIR:-}" ]; then
  /usr/bin/hdiutil detach "${MOUNT_DIR}" -quiet || /usr/bin/hdiutil detach "${MOUNT_DIR}" -force -quiet || true
  rmdir "${MOUNT_DIR}" 2>/dev/null || true
fi

if [ "${RC}" -ne 0 ]; then
  log "FAIL: Splashtop deploy script exited with code ${RC}."
  exit 1
fi

# ---- Post-install verification --------------------------------------------
if [ ! -d "/Applications/Splashtop Streamer.app" ]; then
  log "FAIL: /Applications/Splashtop Streamer.app not present after install."
  exit 1
fi

log "SUCCESS: Splashtop Streamer installed and registered."
exit 0