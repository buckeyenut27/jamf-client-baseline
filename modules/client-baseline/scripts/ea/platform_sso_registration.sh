#!/bin/bash
# EA: Platform SSO Registration (STRING)
# Reports whether the console user has completed Entra Platform SSO
# registration: Registered / Not Registered / No User Session / Unknown.
# Drives the "Platform SSO - Not Registered" smart group.
# ASSUMPTION (check once): parses `app-sso platform -s` output for
# registrationCompleted - verify on a registered test Mac and adjust the
# grep if Apple changes the output format.

consoleUser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && !/loginwindow/ {print $3}')

if [[ -z "$consoleUser" || "$consoleUser" == "root" || "$consoleUser" == "_mbsetupuser" ]]; then
    echo "<result>No User Session</result>"
    exit 0
fi

uid=$(/usr/bin/id -u "$consoleUser" 2>/dev/null)
status=$(/bin/launchctl asuser "$uid" /usr/bin/sudo -u "$consoleUser" /usr/bin/app-sso platform -s 2>/dev/null)

if [[ -z "$status" ]]; then
    echo "<result>Unknown</result>"
elif echo "$status" | /usr/bin/grep -q '"registrationCompleted" *: *true'; then
    echo "<result>Registered</result>"
else
    echo "<result>Not Registered</result>"
fi
