#!/bin/zsh
# =====================================================================
# new-client.sh — start onboarding a new client
# Usage:   ./new-client.sh "Acme Corp"
# Creates  clients/Acme-Corp/  from the template and tells you what's next.
# =====================================================================
set -e

cd "$(dirname "$0")"

if [[ -z "$1" ]]; then
  echo "Usage: ./new-client.sh \"Client Name\""
  exit 1
fi

CLIENT_NAME="$1"
FOLDER_NAME="${CLIENT_NAME// /-}"
TARGET="clients/${FOLDER_NAME}"

if [[ -d "$TARGET" ]]; then
  echo "ERROR: ${TARGET} already exists. Pick a different name or work in that folder."
  exit 1
fi

cp -R "clients/_TEMPLATE" "$TARGET"
cp "${TARGET}/terraform.tfvars.example" "${TARGET}/terraform.tfvars"

# Pre-fill the client name
sed -i '' "s/client_name = \"Acme Corp\"/client_name = \"${CLIENT_NAME}\"/" "${TARGET}/terraform.tfvars"

echo ""
echo "Created ${TARGET}"
echo ""
echo "NEXT STEPS"
echo "  1. PREFERRED: open onboarding-form.html in a browser, fill it out, and"
echo "     save the generated file over ${TARGET}/terraform.tfvars."
echo "     (Manual alternative: edit ${TARGET}/terraform.tfvars and replace"
echo "     every PLACEHOLDER — README.md Step 3 says where each value comes from.)"
echo "  2. Create the Jamf Pro API client for the new tenant:"
echo "       ./bootstrap-api-client.sh https://CLIENT.jamfcloud.com ADMIN_USER"
echo "     and paste the printed ID/secret into the tfvars."
echo "  3. Create the Jamf Protect API client in the Protect console (full"
echo "     read/write role) — README Step 3b."
echo "  4. Drop the client's pkgs into packages/ (Splashtop deploy pkg;"
echo "     Company Portal if Entra+PSSO; S1 pkg if SentinelOne)."
echo "  5. Platform features (Blueprints/passcode/CIS)? Rename platform.tf.off"
echo "     to platform.tf and fill the jamfplatform_* values + tenant UUID."
echo "  6. Then run:"
echo "       cd ${TARGET}"
echo "       terraform init"
echo "       terraform plan"
echo "       terraform apply -parallelism=1"
echo ""
echo "Full instructions: README.md  |  First-apply quirks: README Troubleshooting"
