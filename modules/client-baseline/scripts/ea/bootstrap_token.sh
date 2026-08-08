#!/bin/bash
# EA: Bootstrap Token Escrowed (STRING) — Yes / No
# DDM-enforced software updates on Apple silicon REQUIRE an escrowed
# Bootstrap Token; without one the Mac silently ignores update Blueprints.
# Output phrasing VERIFIED live 2026-08-03:
#   "profiles: Bootstrap Token escrowed to server: NO"
status=$(/usr/bin/profiles status -type bootstraptoken 2>/dev/null)
if echo "$status" | grep -qi "escrowed to server: YES"; then
    echo "<result>Yes</result>"
else
    echo "<result>No</result>"
fi
