#!/bin/bash
# EA: Battery Cycle Count (INTEGER). -1 = no battery (desktop).
# Pattern per jamf/Jamf-Nation-Extension-Attributes Battery_Cycle_Count.
cycleCount=$(ioreg -r -c AppleSmartBattery 2>/dev/null | awk '/"CycleCount" =/ {print $3; exit}')
echo "<result>${cycleCount:--1}</result>"
