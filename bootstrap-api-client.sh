#!/bin/bash
# ============================================================================
# the MSP — Jamf Pro API client bootstrap
#
# Creates, in ONE new client tenant:
#   1. API Role  "MSP Terraform Baseline"  — privileges selected
#      automatically from the tenant's live privilege catalog (no GUI
#      checkbox hunting)
#   2. API Client "msp-terraform"          — scoped to that role
# and prints the Client ID + Client Secret to paste into the onboarding
# form / terraform.tfvars (jamfpro_auth_method = "oauth2").
#
# Usage:
#   ./bootstrap-api-client.sh https://CLIENT.jamfcloud.com ADMIN_USERNAME
#
# The admin username must be a LOCAL Jamf Pro admin (SSO admins cannot
# basic-auth to the API). You'll be prompted for the password — it is used
# once to get a token and never stored.
#
# NOTE: this covers Jamf PRO only. The Jamf Protect API client (and the
# optional Jamf Platform client) are still created in their own consoles —
# see README Step 3b / 3c.
# ============================================================================

set -u

if [ $# -lt 2 ]; then
  echo "Usage: $0 https://CLIENT.jamfcloud.com ADMIN_USERNAME"
  exit 1
fi

URL="${1%/}"
ADMIN="$2"
ROLE_NAME="MSP Terraform Baseline"
CLIENT_NAME="msp-terraform"

# Privilege selection: any privilege whose name contains one of these
# keywords is included (matched against the tenant's live catalog, so
# renamed privileges self-heal). Keep in sync with what the Terraform
# module actually manages.
# VERIFIED against the live the pilot tenant catalog 2026-08-03: App Installer
# privileges are named "Mac Applications"; PreStage needs the Device
# Enrollment Program instance read.
KEYWORDS=(
  "Categories"
  "Smart Computer Groups"
  "Scripts"
  "Policies"
  "macOS Configuration Profiles"
  "Packages"
  "Computer Extension Attributes"
  "Computer PreStage Enrollments"
  "Disk Encryption"
  "Mac Applications"
  "Self Service"
  "Jamf Cloud Distribution Service"
  "Device Enrollment Program Instances"
  "Computer Check-In"
  "Computer Inventory Collection"
)

# Never grant these even if a keyword matches (least privilege):
EXCLUDES=(
  "View Disk Encryption Recovery Key"
)

printf "Password for %s @ %s: " "$ADMIN" "$URL"
read -rs PASSWORD
echo ""

echo "--- Getting token..."
TOKEN=$(curl -s -u "$ADMIN:$PASSWORD" -X POST "$URL/api/v1/auth/token" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
if [ -z "$TOKEN" ]; then
  echo "FAILED to authenticate. Check the URL, username (must be a LOCAL admin), and password."
  exit 1
fi
AUTH="Authorization: Bearer $TOKEN"

echo "--- Fetching the tenant's privilege catalog..."
BODYFILE=$(mktemp)
STATUS=$(curl -s -o "$BODYFILE" -w "%{http_code}" -L \
  -H "$AUTH" -H "Accept: application/json" \
  "$URL/api/v1/api-role-privileges")

if [ "$STATUS" != "200" ] || [ ! -s "$BODYFILE" ]; then
  echo "FAILED: privilege catalog request returned HTTP $STATUS."
  echo "Response body:"; cat "$BODYFILE"; rm -f "$BODYFILE"
  echo ""
  echo "Common causes:"
  echo "  401/empty  - token rejected (SSO-backed or disabled account)"
  echo "  403        - this admin lacks 'Read' on API Roles"
  echo "  404        - endpoint moved; check Jamf Pro version"
  exit 1
fi

# NB: catalog is passed as a FILE argument — do not pipe to python while
# also using a heredoc for the program; the heredoc claims stdin.
PRIVS=$(/usr/bin/python3 - "$BODYFILE" "${#KEYWORDS[@]}" "${KEYWORDS[@]}" "${EXCLUDES[@]}" <<'EOF'
import sys, json
catfile = sys.argv[1]
nkw = int(sys.argv[2])
keywords = [k.lower() for k in sys.argv[3:3+nkw]]
excludes = set(sys.argv[3+nkw:])
data = json.load(open(catfile))
all_privs = data.get("privileges", [])
picked = sorted({p for p in all_privs
                 if any(k in p.lower() for k in keywords)
                 and p not in excludes})
print(json.dumps(picked))
EOF
) || { echo "FAILED to parse catalog. Raw response:"; cat "$BODYFILE"; rm -f "$BODYFILE"; exit 1; }
rm -f "$BODYFILE"

COUNT=$(printf '%s' "$PRIVS" | /usr/bin/python3 -c 'import sys,json;print(len(json.load(sys.stdin)))' 2>/dev/null)
if [ -z "$COUNT" ] || [ "$COUNT" = "0" ]; then
  echo "FAILED: no privileges matched — API shape may have changed. Raw catalog follows:"
  printf '%s\n' "$CATALOG"
  exit 1
fi

echo ""
echo "=== $COUNT privileges selected for role '$ROLE_NAME' ==="
printf '%s' "$PRIVS" | /usr/bin/python3 -c 'import sys,json; [print("  -",p) for p in json.load(sys.stdin)]'
echo ""
printf "Create role + API client in %s? [y/N] " "$URL"
read -r OK
if [ "$OK" != "y" ] && [ "$OK" != "Y" ]; then
  echo "Aborted — nothing created."
  exit 0
fi

echo "--- Creating API role..."
ROLE_RESP=$(printf '%s' "$PRIVS" | /usr/bin/python3 -c '
import sys, json
print(json.dumps({"displayName": "'"$ROLE_NAME"'", "privileges": json.load(sys.stdin)}))
' | curl -s -H "$AUTH" -H "Content-Type: application/json" -X POST "$URL/api/v1/api-roles" -d @-)
ROLE_ID=$(printf '%s' "$ROLE_RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')
if [ -z "$ROLE_ID" ]; then
  echo "FAILED to create role. Response: $ROLE_RESP"
  echo "(A role named '$ROLE_NAME' may already exist — delete it in Settings > API Roles and Clients, or reuse it.)"
  exit 1
fi
echo "    Role created (id $ROLE_ID)."

echo "--- Creating API client..."
INT_RESP=$(curl -s -H "$AUTH" -H "Content-Type: application/json" -X POST "$URL/api/v1/api-integrations" \
  -d "{\"displayName\":\"$CLIENT_NAME\",\"enabled\":true,\"accessTokenLifetimeSeconds\":1800,\"authorizationScopes\":[\"$ROLE_NAME\"]}")
INT_ID=$(printf '%s' "$INT_RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')
if [ -z "$INT_ID" ]; then
  echo "FAILED to create API client. Response: $INT_RESP"
  exit 1
fi

CRED_RESP=$(curl -s -H "$AUTH" -X POST "$URL/api/v1/api-integrations/$INT_ID/client-credentials")
CLIENT_ID=$(printf '%s' "$CRED_RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("clientId",""))')
CLIENT_SECRET=$(printf '%s' "$CRED_RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("clientSecret",""))')
if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "FAILED to generate credentials. Response: $CRED_RESP"
  exit 1
fi

echo ""
echo "============================================================"
echo "  SUCCESS — paste these into the onboarding form / tfvars:"
echo ""
echo "  jamfpro_auth_method   = \"oauth2\""
echo "  jamfpro_client_id     = \"$CLIENT_ID\""
echo "  jamfpro_client_secret = \"$CLIENT_SECRET\""
echo ""
echo "  The secret is shown ONCE — store it in 1Password NOW."
echo "  Still manual: Jamf Protect API client (Protect console >"
echo "  Administrative > API Clients, full read/write role) and,"
echo "  if Platform features are on, the Jamf Account API client."
echo "============================================================"
