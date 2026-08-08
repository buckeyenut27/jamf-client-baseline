#!/bin/bash
# =============================================================================
# Create/repair the MSP service admin account — run by Jamf Pro policy
#
# Jamf script parameters (set automatically by the Terraform-managed policy):
#   $4 = account password
#   $5 = account username (default: msp_admin)
#
# Behavior (self-healing, safe to run repeatedly):
#   - Account missing  -> create it: hidden, admin, home under /private/var
#   - Account exists   -> ensure it is in the admin group and hidden
#
# SECURE TOKEN NOTE: accounts created by this script after FileVault is
# enabled do NOT get a Secure Token, so they cannot unlock FileVault at boot.
# That's expected: the PreStage-created copy of this account (made during
# Setup Assistant) does get a token, and the escrowed Individual Recovery Key
# in Jamf Pro is the FileVault fallback either way. This account's job is
# post-unlock local admin access (lockout protection, support work).
# =============================================================================

PASSWORD="$4"
USERNAME="${5:-msp_admin}"

if [[ -z "$PASSWORD" ]]; then
    echo "ERROR: account password (parameter 4) is empty. Check terraform.tfvars."
    exit 1
fi

ensure_admin_and_hidden() {
    /usr/sbin/dseditgroup -o edit -a "$USERNAME" -t user admin 2>/dev/null
    /usr/bin/dscl . -create "/Users/$USERNAME" IsHidden 1
}

if /usr/bin/id "$USERNAME" >/dev/null 2>&1; then
    echo "$USERNAME already exists - verifying admin membership and hidden flag."
    ensure_admin_and_hidden
    if /usr/sbin/dseditgroup -o checkmember -m "$USERNAME" admin >/dev/null 2>&1; then
        echo "OK: $USERNAME is an admin and hidden."
        exit 0
    else
        echo "ERROR: could not confirm admin membership for $USERNAME."
        exit 1
    fi
fi

echo "Creating $USERNAME..."
/usr/sbin/sysadminctl -addUser "$USERNAME" \
    -fullName "MSP Admin" \
    -password "$PASSWORD" \
    -home "/private/var/$USERNAME" \
    -admin

if ! /usr/bin/id "$USERNAME" >/dev/null 2>&1; then
    echo "ERROR: sysadminctl did not create $USERNAME."
    exit 1
fi

ensure_admin_and_hidden

if /usr/sbin/dseditgroup -o checkmember -m "$USERNAME" admin >/dev/null 2>&1; then
    echo "SUCCESS: $USERNAME created (hidden, admin, home /private/var/$USERNAME)."
    exit 0
else
    echo "ERROR: $USERNAME created but admin membership could not be confirmed."
    exit 1
fi
