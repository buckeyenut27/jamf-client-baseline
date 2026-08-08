#!/bin/bash
# =============================================================================
# DDM fixer — re-sync the declarative management channel.
#
# Runs on Macs in the "DDM - Not Enabled" smart group (DDM Status EA reports
# Disabled). `profiles renew -type enrollment` re-runs enrollment tasks and
# re-establishes the MDM/DDM sync — the standard remediation for a stuck
# declarative channel. Silent on device-enrolled (ADE/PreStage) Macs.
# =============================================================================
echo "Renewing MDM enrollment to kick DDM sync..."
/usr/bin/profiles renew -type enrollment
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: profiles renew exited $rc"
    exit 1
fi
echo "Renew requested. DDM status is re-evaluated at next inventory."
exit 0
