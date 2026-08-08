#!/bin/bash
# EA: Battery Condition (STRING) — Normal / Service Recommended / No Battery.
condition=$(system_profiler SPPowerDataType 2>/dev/null | awk -F': ' '/Condition/ {print $2; exit}')
echo "<result>${condition:-No Battery}</result>"
