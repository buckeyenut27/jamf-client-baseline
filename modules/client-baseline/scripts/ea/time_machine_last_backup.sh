#!/bin/bash
# EA: Time Machine Last Backup (STRING)
# Shows the date of the newest completed TM backup, or whether TM is even
# configured. Requires the jamf binary's Full Disk Access (standard on
# managed Macs).
latest=$(tmutil latestbackup 2>/dev/null | tail -1)
if [[ -n "$latest" ]]; then
    echo "<result>$(basename "$latest" | cut -d. -f1)</result>"
elif tmutil destinationinfo 2>/dev/null | grep -q "Name"; then
    echo "<result>Configured - No Completed Backups</result>"
else
    echo "<result>Not Configured</result>"
fi
