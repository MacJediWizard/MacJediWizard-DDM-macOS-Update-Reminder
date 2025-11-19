#!/bin/bash

# create-pkg.sh - Create installer package for DDMmacOSUpdateReminder
#
# Creates a signed and notarized .pkg installer that:
#   - Installs binary to /usr/local/bin/
#   - Can be deployed via Jamf Pro
#
# Prerequisites:
#   - Run sign-and-notarize.sh first to build and sign the binary
#   - Developer ID Installer certificate in Keychain
#
# Usage:
#   ./scripts/create-pkg.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PRODUCT_NAME="DDMmacOSUpdateReminder"
VERSION="1.0.0"
IDENTIFIER="com.macjediwizard.ddmmacosupdatereminder"

# Configuration
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-notarytool-profile}"

cd "$PROJECT_ROOT"

# Auto-detect Developer ID Installer certificate
if [[ -z "$INSTALLER_CERT" ]]; then
    INSTALLER_CERT=$(security find-identity -v | grep "Developer ID Installer" | head -1 | sed 's/.*"\(.*\)".*/\1/')

    if [[ -z "$INSTALLER_CERT" ]]; then
        echo "ERROR: No Developer ID Installer certificate found in keychain"
        echo ""
        echo "Available identities:"
        security find-identity -v
        exit 1
    fi

    echo "Auto-detected certificate: $INSTALLER_CERT"
fi

BINARY_PATH=".build/universal/$PRODUCT_NAME"
PKG_ROOT=".build/pkg-root"
PKG_PATH=".build/${PRODUCT_NAME}-${VERSION}.pkg"

echo "============================================"
echo "Creating Installer Package"
echo "============================================"
echo ""

# Check binary exists and is signed
if [[ ! -f "$BINARY_PATH" ]]; then
    echo "ERROR: Binary not found. Run sign-and-notarize.sh first."
    exit 1
fi

# Verify signature
if ! codesign --verify "$BINARY_PATH" 2>/dev/null; then
    echo "ERROR: Binary is not signed. Run sign-and-notarize.sh first."
    exit 1
fi

# Step 1: Create package root structure
echo "Step 1: Creating package structure..."
rm -rf "$PKG_ROOT"
mkdir -p "$PKG_ROOT/usr/local/bin"
cp "$BINARY_PATH" "$PKG_ROOT/usr/local/bin/"
chmod 755 "$PKG_ROOT/usr/local/bin/$PRODUCT_NAME"

# Step 2: Build component package
echo ""
echo "Step 2: Building installer package..."
pkgbuild \
    --root "$PKG_ROOT" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location "/" \
    ".build/${PRODUCT_NAME}-component.pkg"

# Step 3: Create distribution package (optional, for customization)
# For a simple binary, the component package is sufficient

# Step 4: Sign the package
echo ""
echo "Step 3: Signing installer package..."
productsign \
    --sign "$INSTALLER_CERT" \
    ".build/${PRODUCT_NAME}-component.pkg" \
    "$PKG_PATH"

rm ".build/${PRODUCT_NAME}-component.pkg"

# Verify package signature
echo "Verifying package signature..."
pkgutil --check-signature "$PKG_PATH"

# Step 5: Notarize the package
echo ""
echo "Step 4: Submitting package for notarization..."
xcrun notarytool submit "$PKG_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait

# Step 6: Staple the notarization ticket
echo ""
echo "Step 5: Stapling notarization ticket..."
xcrun stapler staple "$PKG_PATH"

# Verify staple
xcrun stapler validate "$PKG_PATH"

# Clean up
rm -rf "$PKG_ROOT"

echo ""
echo "============================================"
echo "Package Creation Complete!"
echo "============================================"
echo ""
echo "Installer package: $PKG_PATH"
echo ""
echo "This package can be:"
echo "  - Deployed via Jamf Pro"
echo "  - Distributed directly to users"
echo "  - Installed with: sudo installer -pkg $PKG_PATH -target /"
