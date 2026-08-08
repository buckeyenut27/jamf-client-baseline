#!/bin/bash
# EA: Huntress Agent Version (STRING)
# Smart-group this to catch stale agents the portal hasn't flagged yet.
app="/Applications/Huntress.app"
if [[ -d "$app" ]]; then
    echo "<result>$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null)</result>"
else
    echo "<result>Not Installed</result>"
fi
