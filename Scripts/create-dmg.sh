#!/usr/bin/env bash
set -euo pipefail

# Creates a styled DMG installer for The Annex
# No external dependencies — uses hdiutil + AppleScript
#
# Usage: ./Scripts/create-dmg.sh [app-bundle-path] [output-dmg-path]
#
# Example:
#   ./Scripts/create-dmg.sh .build/TheAnnex.app .build/TheAnnex.dmg

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_PATH="${1:-.build/TheAnnex.app}"
OUTPUT_DMG="${2:-.build/TheAnnex.dmg}"
APP_NAME="$(basename "$APP_PATH" .app)"
VOLUME_NAME="The Annex"

DMG_STAGING=".build/dmg-staging"
DMG_RW=".build/dmg-rw.dmg"

# Validate app bundle exists
if [ ! -d "$APP_PATH" ]; then
    echo "✗ App bundle not found: $APP_PATH"
    exit 1
fi

# Detach any leftover volumes
hdiutil detach "/Volumes/$VOLUME_NAME" -force 2>/dev/null || true

# Clean previous artifacts
rm -rf "$DMG_STAGING" "$DMG_RW" "$OUTPUT_DMG"

echo "==> Generating DMG background..."
swift "$SCRIPT_DIR/generate-dmg-background.swift" ".build"

echo "==> Staging DMG contents..."
mkdir -p "$DMG_STAGING/.background"
cp .build/dmg-background.png "$DMG_STAGING/.background/background.png"
cp .build/dmg-background@2x.png "$DMG_STAGING/.background/background@2x.png"
cp -R "$APP_PATH" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Creating read-write disk image..."
hdiutil create \
    -srcfolder "$DMG_STAGING" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -format UDRW \
    -size 20m \
    -ov \
    "$DMG_RW"

# Detect headless/CI: skip AppleScript styling if Finder isn't available
IS_HEADLESS=false
if [ -n "${CI:-}" ] || ! pgrep -q WindowServer 2>/dev/null; then
    IS_HEADLESS=true
fi

if [ "$IS_HEADLESS" = true ]; then
    echo "==> CI detected — using pre-built .DS_Store template"
    if [ -f "$SCRIPT_DIR/dmg-template/DS_Store" ]; then
        # Mount read-write, copy in the template .DS_Store, detach
        DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_RW" | head -1 | awk '{print $1}')
        MOUNT_DIR=$(hdiutil info | grep "$VOLUME_NAME" | awk -F'\t' '{print $NF}' | xargs)
        cp "$SCRIPT_DIR/dmg-template/DS_Store" "$MOUNT_DIR/.DS_Store"
        sync
        hdiutil detach "$DEVICE" -quiet 2>/dev/null || hdiutil detach "$DEVICE" -force
    else
        echo "  ⚠ No DS_Store template found — DMG will use default Finder layout"
    fi
else
    echo "==> Mounting and styling with Finder..."
    DEVICE=$(hdiutil attach -readwrite -noverify "$DMG_RW" | head -1 | awk '{print $1}')
    sleep 3

    # Style the Finder window via AppleScript
    osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        delay 2
        
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 760, 528}
        
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.png"
        
        set position of item "$APP_NAME.app" of container window to {155, 195}
        set position of item "Applications" of container window to {495, 195}
        
        close
        open
        delay 1
        close
    end tell
end tell
EOF

    sync
    sleep 2

    echo "==> Detaching..."
    hdiutil detach "$DEVICE" -quiet 2>/dev/null || hdiutil detach "$DEVICE" -force
fi

echo "==> Compressing to final DMG..."
hdiutil convert "$DMG_RW" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$OUTPUT_DMG"

echo "==> Cleaning up..."
rm -rf "$DMG_STAGING" "$DMG_RW"

DMG_SIZE=$(du -h "$OUTPUT_DMG" | cut -f1 | xargs)
echo ""
echo "✓ DMG created: $OUTPUT_DMG ($DMG_SIZE)"
