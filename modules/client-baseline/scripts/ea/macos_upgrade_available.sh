#!/bin/zsh --no-rcs
# shellcheck shell=bash
# EA: macOS Upgrade Available (STRING) — Yes / No / Unknown
#
# Compares this Mac's running macOS major version against the highest major
# its model supports, per the SOFA feed (sofa.macadmins.io). Smart-group on
# "Yes" to find Macs behind their hardware ceiling before enforcing upgrades.
#
# Reuses the SOFA JSON cache maintained by the "Max Supported macOS Version"
# EA at /private/var/tmp/sofa/ and refreshes it when older than a day.

system_version=$(/usr/bin/sw_vers -productVersion)
system_major=${system_version%%.*}

online_json_url="https://sofafeed.macadmins.io/v1/macos_data_feed.json"
user_agent="SOFA-Jamf-EA-UpgradeAvailable/1.0"
json_cache_dir="/private/var/tmp/sofa"
json_cache="$json_cache_dir/macos_data_feed.json"

/bin/mkdir -p "$json_cache_dir"
if [[ ! -f "$json_cache" || -n $(/usr/bin/find "$json_cache" -mtime +1 2>/dev/null) ]]; then
    /usr/bin/curl --compressed --location --max-time 5 --silent \
        --header "User-Agent: $user_agent" "$online_json_url" --output "$json_cache"
fi

if [[ ! -s "$json_cache" ]]; then
    echo "<result>Unknown</result>"
    exit 0
fi

model=$(/usr/sbin/sysctl -n hw.model)
# Virtual Macs support all current OSes; use an M1 mini as a stand-in.
[[ $model == VirtualMac* ]] && model="Macmini9,1"

latest=$(/usr/bin/plutil -extract "Models.$model.SupportedOS.0" raw -expect string "$json_cache" 2>/dev/null | /usr/bin/head -n 1)
latest_major=$(echo "$latest" | /usr/bin/grep -oE '[0-9]+' | /usr/bin/tail -1)

if [[ -z "$latest_major" || -z "$system_major" ]]; then
    echo "<result>Unknown</result>"
elif (( system_major < latest_major )); then
    echo "<result>Yes</result>"
else
    echo "<result>No</result>"
fi
exit 0
