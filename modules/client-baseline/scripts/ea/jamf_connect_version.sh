#!/bin/bash
# EA: Jamf Connect Version (STRING)
app="/Applications/Jamf Connect.app"
if [[ -d "$app" ]]; then
    echo "<result>$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null)</result>"
else
    echo "<result>Not Installed</result>"
fi
