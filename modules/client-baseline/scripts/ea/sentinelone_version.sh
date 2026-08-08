#!/bin/bash
# EA: SentinelOne Agent Version (STRING)
if [[ -x /usr/local/bin/sentinelctl ]]; then
    version=$(/usr/local/bin/sentinelctl version 2>/dev/null | head -1)
    echo "<result>${version:-Installed - version unknown}</result>"
else
    echo "<result>Not Installed</result>"
fi
