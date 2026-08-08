#!/bin/bash
# EA: DDM Status (STRING) — Enabled / Disabled / Unknown
# Whether the Mac's Declarative Device Management channel is active. Macs
# reporting Disabled will not honor Blueprints (DDM) enforcement — the
# "DDM - Kick Enrollment" policy remediates them.
#
# Detection, two signals (VERIFIED live 2026-08-03 that `profiles status
# -type enrollment` does NOT include a DDM line on all macOS versions —
# hence the fallback):
#   1. A "Declarative Device Management" line in profiles status, when the
#      macOS version provides one.
#   2. The DDM software-update state file — present once the Mac has
#      received declarative software update declarations (i.e. the channel
#      demonstrably works for the thing we care about: update Blueprints).
# Neither signal conclusive -> Unknown (the fixer policy ignores Unknown).

ddm_line=$(/usr/bin/profiles status -type enrollment 2>/dev/null | grep -i "declarative")

if [ -n "$ddm_line" ]; then
    if echo "$ddm_line" | grep -qi "enabled"; then
        echo "<result>Enabled</result>"
    else
        echo "<result>Disabled</result>"
    fi
    exit 0
fi

if [ -f "/private/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist" ]; then
    echo "<result>Enabled</result>"
else
    echo "<result>Unknown</result>"
fi
