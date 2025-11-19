#!/bin/bash

# sign-and-notarize.sh - Code sign and notarize DDMmacOSUpdateReminder
#
# Prerequisites:
#   - Apple Developer ID Application certificate in Keychain
#   - App-specific password stored in Keychain for notarytool
#
# Setup (one-time):
#   xcrun notarytool store-credentials "notarytool-profile" \
#     --apple-id "your-apple-id@example.com" \
#     --team-id "YOUR_TEAM_ID" \
#     --password "app-specific-password"
#
# Usage:
#   ./scripts/sign-and-notarize.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PRODUCT_NAME="DDMmacOSUpdateReminder"

# Configuration
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-notarytool-profile}"

cd "$PROJECT_ROOT"

# Auto-detect Developer ID Application certificate
if [[ -z "$DEVELOPER_ID" ]]; then
    DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')

    if [[ -z "$DEVELOPER_ID" ]]; then
        echo "ERROR: No Developer ID Application certificate found in keychain"
        echo ""
        echo "Available code signing identities:"
        security find-identity -v -p codesigning
        exit 1
    fi

    echo "Auto-detected certificate: $DEVELOPER_ID"
fi

echo "============================================"
echo "DDMmacOSUpdateReminder Sign & Notarize"
echo "============================================"
echo ""

# Step 1: Build universal release binary
echo "Step 1: Building universal release binary..."
./scripts/build.sh universal

BINARY_PATH=".build/universal/$PRODUCT_NAME"

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "ERROR: Binary not found at $BINARY_PATH"
    exit 1
fi

# Step 2: Code sign
echo ""
echo "Step 2: Code signing with Developer ID..."
codesign --force --options runtime --sign "$DEVELOPER_ID" "$BINARY_PATH"

# Verify signature
echo "Verifying signature..."
codesign --verify --verbose "$BINARY_PATH"

# Step 3: Create ZIP for notarization
echo ""
echo "Step 3: Creating ZIP for notarization..."
ZIP_PATH=".build/$PRODUCT_NAME.zip"
ditto -c -k --keepParent "$BINARY_PATH" "$ZIP_PATH"

# Step 4: Submit for notarization
echo ""
echo "Step 4: Submitting for notarization..."
echo "This may take a few minutes..."

xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

# Step 5: Staple (Note: Can't staple bare binaries, only app bundles/dmg/pkg)
echo ""
echo "============================================"
echo "Notarization Complete!"
echo "============================================"
echo ""
echo "Signed binary: $BINARY_PATH"
echo ""
echo "Note: Bare binaries cannot be stapled. The notarization"
echo "ticket will be retrieved from Apple's servers when users"
echo "run the binary for the first time (requires internet)."
echo ""
echo "To install:"
echo "  sudo cp $BINARY_PATH /usr/local/bin/"
echo "  sudo chmod 755 /usr/local/bin/$PRODUCT_NAME"
echo ""
echo "To create a distributable package (recommended):"
echo "  ./scripts/create-pkg.sh"
