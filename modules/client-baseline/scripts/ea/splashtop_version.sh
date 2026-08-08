#!/bin/bash
# EA: Splashtop Streamer Version (STRING)
app="/Applications/Splashtop Streamer.app"
if [[ -d "$app" ]]; then
    echo "<result>$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null)</result>"
else
    echo "<result>Not Installed</result>"
fi
