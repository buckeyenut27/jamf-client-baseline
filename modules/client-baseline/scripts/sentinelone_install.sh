#!/bin/bash
###################################################################################################
# Script Name:  Install and Register SentinelOne
# Description:  Creates registration token and installs SentinelOne agent
# Author:       Jackson Pavelka
# Created:      October 17, 2025
# Updated:      June 11, 2026 - Parameterized token and package name for Jamf script parameters
#
# Jamf Pro Script Parameters:
#   Parameter 4: SentinelOne registration token (base64 string)
#   Parameter 5: Package file name (e.g., Sentinel-Release_macos_v25_3_1_8253.pkg)
###################################################################################################

# Variables (from Jamf script parameters)
REGISTRATION_TOKEN="$4"
PACKAGE_NAME="$5"

WAITING_ROOM="/Library/Application Support/JAMF/Waiting Room"
TOKEN_FILE="$WAITING_ROOM/com.sentinelone.registration-token"
PACKAGE_PATH="$WAITING_ROOM/$PACKAGE_NAME"

echo "Starting SentinelOne installation process..."

# Step 0: Validate script parameters
if [ -z "$REGISTRATION_TOKEN" ]; then
    echo "ERROR: Registration token not provided. Set Jamf script Parameter 4."
    exit 1
fi

if [ -z "$PACKAGE_NAME" ]; then
    echo "ERROR: Package name not provided. Set Jamf script Parameter 5."
    exit 1
fi

echo "✓ Parameters validated"
echo "  Package: $PACKAGE_NAME"

# Step 1: Verify package exists in Waiting Room
if [ ! -f "$PACKAGE_PATH" ]; then
    echo "ERROR: SentinelOne package not found at: $PACKAGE_PATH"
    echo "Available files in Waiting Room:"
    ls -la "$WAITING_ROOM"
    exit 1
fi

echo "✓ Package found: $PACKAGE_PATH"

# Step 2: Create registration token
echo "Creating registration token..."
echo "$REGISTRATION_TOKEN" > "$TOKEN_FILE"

if [ -f "$TOKEN_FILE" ]; then
    chmod 644 "$TOKEN_FILE"
    echo "✓ Registration token created successfully (${#REGISTRATION_TOKEN} characters)"
else
    echo "ERROR: Failed to create registration token"
    exit 1
fi

# Step 3: Install SentinelOne
echo "Installing SentinelOne agent..."
/usr/sbin/installer -pkg "$PACKAGE_PATH" -target / -verbose
INSTALL_EXIT_CODE=$?

if [ $INSTALL_EXIT_CODE -eq 0 ]; then
    echo "✓ SentinelOne installed successfully"
else
    echo "ERROR: Installation failed with exit code: $INSTALL_EXIT_CODE"
    exit 1
fi

# Step 4: Wait for agent to initialize
echo "Waiting for agent to initialize..."
sleep 15

# Step 5: Verify installation and registration
if [ -f /usr/local/bin/sentinelctl ]; then
    echo "Checking agent status..."
    /usr/local/bin/sentinelctl status

    echo ""
    echo "Checking management URL..."
    /usr/local/bin/sentinelctl management url get

    echo ""
    echo "Testing connectivity..."
    /usr/local/bin/sentinelctl management connectivity check
else
    echo "WARNING: sentinelctl not found - agent may still be initializing"
fi

# Step 6: Cleanup (optional)
echo "Cleaning up registration token..."
rm -f "$TOKEN_FILE"

echo "SentinelOne installation complete!"
exit 0