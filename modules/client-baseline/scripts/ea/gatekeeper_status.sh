#!/bin/bash
# EA: Gatekeeper Status (STRING) — Enabled / Disabled.
if spctl --status 2>/dev/null | grep -q "assessments enabled"; then
    echo "<result>Enabled</result>"
else
    echo "<result>Disabled</result>"
fi
