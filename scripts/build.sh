#!/bin/bash

# build.sh - Build DDMmacOSUpdateReminder
#
# Usage:
#   ./scripts/build.sh              # Debug build
#   ./scripts/build.sh release      # Release build
#   ./scripts/build.sh clean        # Clean build artifacts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PRODUCT_NAME="DDMmacOSUpdateReminder"

cd "$PROJECT_ROOT"

case "${1:-debug}" in
    debug)
        echo "Building debug configuration..."
        swift build
        echo ""
        echo "Debug build complete."
        echo "Binary location: .build/debug/$PRODUCT_NAME"
        ;;

    release)
        echo "Building release configuration..."
        swift build -c release
        echo ""
        echo "Release build complete."
        echo "Binary location: .build/release/$PRODUCT_NAME"
        echo ""
        echo "To install system-wide:"
        echo "  sudo cp .build/release/$PRODUCT_NAME /usr/local/bin/"
        echo "  sudo chmod 755 /usr/local/bin/$PRODUCT_NAME"
        ;;

    clean)
        echo "Cleaning build artifacts..."
        swift package clean
        rm -rf .build
        echo "Clean complete."
        ;;

    universal)
        echo "Building universal binary (arm64 + x86_64)..."

        # Build for both architectures
        swift build -c release --arch arm64
        swift build -c release --arch x86_64

        # Create universal binary
        mkdir -p .build/universal
        lipo -create \
            .build/arm64-apple-macosx/release/$PRODUCT_NAME \
            .build/x86_64-apple-macosx/release/$PRODUCT_NAME \
            -output .build/universal/$PRODUCT_NAME

        echo ""
        echo "Universal build complete."
        echo "Binary location: .build/universal/$PRODUCT_NAME"
        ;;

    *)
        echo "Usage: $0 [debug|release|universal|clean]"
        echo ""
        echo "Commands:"
        echo "  debug     - Build debug configuration (default)"
        echo "  release   - Build release configuration"
        echo "  universal - Build universal binary (arm64 + x86_64)"
        echo "  clean     - Remove build artifacts"
        exit 1
        ;;
esac
