#!/bin/bash
# EA: Days Since Last Reboot (INTEGER)
# Helpdesk triage: long-uptime Macs correlate with weird behavior and
# un-applied updates. Pattern per palantir/jamf-pro-scripts Uptime EA.
bootEpoch=$(sysctl -n kern.boottime | awk -F'[ ,]' '{print $4}')
nowEpoch=$(date +%s)
if [[ -z "$bootEpoch" ]]; then
    echo "<result>-1</result>"
else
    echo "<result>$(( (nowEpoch - bootEpoch) / 86400 ))</result>"
fi
