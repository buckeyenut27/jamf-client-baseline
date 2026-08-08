#!/bin/bash
# EA: Local Admin Accounts (STRING)
# MSP audit staple: who has admin on this Mac? Filters root and service
# accounts (_*). Pair with a smart group to catch unexpected admins.
members=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/^GroupMembership: //')
result=""
for user in $members; do
    [[ "$user" == "root" || "$user" == _* ]] && continue
    result+="$user "
done
echo "<result>${result:-None}</result>"
