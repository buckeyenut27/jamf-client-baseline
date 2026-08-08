#!/bin/zsh --no-rcs
# shellcheck shell=bash

# EA: Maximum Supported macOS Version (STRING)
# Reports the highest macOS major version this Mac model can run, using the
# SOFA feed (sofa.macadmins.io). Upgrade-planning gold: smart-group on this
# to find Macs that can't take the next major version before it's enforced.
#
# Source: macadmins/sofa tool-scripts/macOSCompatibilityCheck-EA.sh
# by Balz Aschwanden, adapted from Graham Pugh.
# MSP MODIFICATION (2026-06-11): result reports the latest compatible
# macOS version string instead of Pass/Fail.

# Get current system OS
system_version=$( /usr/bin/sw_vers -productVersion )

system_os=$(cut -d. -f1 <<< "$system_version")
echo "System Version: $system_version"

if [[ $system_os -ge 12 ]]; then
    # use plistlib
    os_compatibility="current"
else
    # use python 2.7
    os_compatibility="legacy"
    python_path="/usr/bin/python"
fi

# URL to the online JSON data
online_json_url="https://sofafeed.macadmins.io/v1/macos_data_feed.json"
user_agent="SOFA-Jamf-EA-macOSCompatibilityCheck/1.1"

# local store
json_cache_dir="/private/var/tmp/sofa"
json_cache="$json_cache_dir/macos_data_feed.json"
etag_cache="$json_cache_dir/macos_data_feed_etag.txt"
etag_cache_temp="$json_cache_dir/macos_data_feed_etag_temp.txt"

# ensure local cache folder exists
/bin/mkdir -p "$json_cache_dir"

# check local vs online using etag (only available on macOS 12+)
if [[ -f "$etag_cache" && -f "$json_cache" ]]; then
    etag_old=$(/bin/cat "$etag_cache")
    /usr/bin/curl --compressed --silent --etag-compare "$etag_cache" --etag-save "$etag_cache_temp" --header "User-Agent: $user_agent" "$online_json_url" --output "$json_cache"
    etag_temp=$(/bin/cat "$etag_cache_temp")
    if [[ "$etag_old" == "$etag_temp" || $etag_temp == "" ]]; then
        echo "Cached ETag matched online ETag - cached json file is up to date"
        /bin/rm "$etag_cache_temp"
    else
        echo "Cached ETag did not match online ETag, so downloaded new SOFA json file"
        /bin/mv "$etag_cache_temp" "$etag_cache"
    fi
elif [[ "$os_compatibility" == "legacy" ]]; then
    echo "OS not compatible with e-tags, proceeding to download SOFA json file"
    /usr/bin/curl --compressed --location --max-time 3 --silent --header "User-Agent: $user_agent" "$online_json_url" --output "$json_cache"
else
    echo "No e-tag or SOFA json file cached, proceeding to download SOFA json file"
    /usr/bin/curl --compressed --location --max-time 3 --silent --header "User-Agent: $user_agent" "$online_json_url" --etag-save "$etag_cache" --output "$json_cache"
fi

echo

if [[ ! -f "$json_cache" ]]; then
    echo "<result>Could not obtain data</result>"
    exit
elif [[ "$os_compatibility" == "legacy" ]]; then
    if ! "$python_path" -c 'import sys, json; print json.load(sys.stdin)["UpdateHash"]' < "$json_cache" > /dev/null; then
        echo "<result>Could not obtain data</result>"
        exit
    fi
elif ! /usr/bin/plutil -extract "UpdateHash" raw "$json_cache" > /dev/null; then
    echo "<result>Could not obtain data</result>"
    exit
fi

# Get model (DeviceID)
model=$(/usr/sbin/sysctl -n hw.model)
if [[ -z "$model" ]]; then
    echo "<result>Could not obtain model</result>"
    exit
fi
echo "Model Identifier: $model"

# check that the model is virtual or is in the feed at all
if [[ $model == "VirtualMac"* ]]; then
    # if virtual, we need to arbitrarily choose a model that supports all current OSes. Plucked for an M1 Mac mini
    model="Macmini9,1"
elif ! grep -q "$model" "$json_cache"; then
    echo "<result>Unsupported Hardware</result>"
    exit
fi

if [[ "$os_compatibility" == "current" ]]; then
    # identify the latest compatible major OS (macOS 12+ method)
    latest_compatible_os=$(/usr/bin/plutil -extract "Models.$model.SupportedOS.0" raw -expect string "$json_cache" | /usr/bin/head -n 1)
else
    # identify the latest compatible major OS (macOS 11- method)
    latest_compatible_os=$("$python_path" -c 'import sys, json; print json.load(sys.stdin)["Models"]["'$model'"]["SupportedOS"][0]' < "$json_cache" | /usr/bin/head -n 1)
fi
echo "Latest Compatible macOS: $latest_compatible_os"

# MSP MODIFICATION: report the version itself, not Pass/Fail
if [[ -n "$latest_compatible_os" ]]; then
    echo "<result>$latest_compatible_os</result>"
else
    echo "<result>Unknown</result>"
fi
