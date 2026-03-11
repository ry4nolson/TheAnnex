#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="TheAnnex"
EXEC_NAME="TheAnnex"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
DEST_DIR="$HOME/Applications"

echo "==> Creating app bundle structure..."
mkdir -p "$MACOS"

echo "==> Compiling Swift files..."
swiftc \
    "$SCRIPT_DIR/main.swift" \
    "$SCRIPT_DIR/Models/NASState.swift" \
    "$SCRIPT_DIR/Models/NASDevice.swift" \
    "$SCRIPT_DIR/Models/SyncFolder.swift" \
    "$SCRIPT_DIR/Models/SyncJob.swift" \
    "$SCRIPT_DIR/Models/ActivityEntry.swift" \
    "$SCRIPT_DIR/Models/Statistics.swift" \
    "$SCRIPT_DIR/Utilities/ShellHelper.swift" \
    "$SCRIPT_DIR/Utilities/RsyncWrapper.swift" \
    "$SCRIPT_DIR/Utilities/NetworkDetector.swift" \
    "$SCRIPT_DIR/Utilities/NASDiscovery.swift" \
    "$SCRIPT_DIR/Utilities/KeychainHelper.swift" \
    "$SCRIPT_DIR/Utilities/AnnexQuotes.swift" \
    "$SCRIPT_DIR/Controllers/AppState.swift" \
    "$SCRIPT_DIR/Controllers/SyncEngine.swift" \
    "$SCRIPT_DIR/Controllers/NASMonitor.swift" \
    "$SCRIPT_DIR/Controllers/AppDelegate.swift" \
    "$SCRIPT_DIR/Controllers/MainWindowController.swift" \
    "$SCRIPT_DIR/Views/GeneralSettingsView.swift" \
    "$SCRIPT_DIR/Views/SyncFoldersView.swift" \
    "$SCRIPT_DIR/Views/ActivityLogView.swift" \
    "$SCRIPT_DIR/Views/StatisticsView.swift" \
    "$SCRIPT_DIR/Views/AdvancedSettingsView.swift" \
    "$SCRIPT_DIR/Views/AboutView.swift" \
    -o "$MACOS/$EXEC_NAME" \
    -framework Cocoa \
    -framework UserNotifications \
    -framework SwiftUI \
    -framework Combine \
    -framework Charts \
    -framework CoreWLAN \
    -framework IOKit \
    -framework Security \
    -framework UniformTypeIdentifiers \
    -framework Network

echo "==> Copying Info.plist..."
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS/Info.plist"

echo "==> Building app icon..."
ICONSET_DIR="$SCRIPT_DIR/AppIcon.appiconset"
RESOURCES="$CONTENTS/Resources"
mkdir -p "$RESOURCES"
if [ -d "$ICONSET_DIR" ]; then
    ICONSET_TMP="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_TMP"
    cp "$ICONSET_DIR/16.png" "$ICONSET_TMP/icon_16x16.png"
    cp "$ICONSET_DIR/32.png" "$ICONSET_TMP/icon_16x16@2x.png"
    cp "$ICONSET_DIR/32.png" "$ICONSET_TMP/icon_32x32.png"
    cp "$ICONSET_DIR/64.png" "$ICONSET_TMP/icon_32x32@2x.png"
    cp "$ICONSET_DIR/128.png" "$ICONSET_TMP/icon_128x128.png"
    cp "$ICONSET_DIR/256.png" "$ICONSET_TMP/icon_128x128@2x.png"
    cp "$ICONSET_DIR/256.png" "$ICONSET_TMP/icon_256x256.png"
    cp "$ICONSET_DIR/512.png" "$ICONSET_TMP/icon_256x256@2x.png"
    cp "$ICONSET_DIR/512.png" "$ICONSET_TMP/icon_512x512.png"
    cp "$ICONSET_DIR/1024.png" "$ICONSET_TMP/icon_512x512@2x.png"
    iconutil -c icns -o "$RESOURCES/AppIcon.icns" "$ICONSET_TMP"
    rm -rf "$ICONSET_TMP"
    cp "$ICONSET_DIR/256.png" "$RESOURCES/AppIcon.png"
fi

# Copy sponsor logos
SPONSOR_DIR="$SCRIPT_DIR/TexasBeardCo"
if [ -d "$SPONSOR_DIR" ]; then
    cp "$SPONSOR_DIR/HorizontalLogo.png" "$RESOURCES/SponsorLogo.png"
    cp "$SPONSOR_DIR/HorizontalLogoWhite.png" "$RESOURCES/SponsorLogoWhite.png"
fi

echo "==> Code signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Installing to ~/Applications/..."
mkdir -p "$DEST_DIR"

# Kill running app if it exists (check both old and new executable names)
if pgrep -x "$EXEC_NAME" > /dev/null; then
    echo "==> Stopping running $EXEC_NAME..."
    pkill -x "$EXEC_NAME"
    sleep 1
fi

# Remove previous installation if it exists
if [ -d "$DEST_DIR/$APP_NAME.app" ]; then
    echo "==> Removing previous installation..."
    rm -rf "$DEST_DIR/$APP_NAME.app"
fi

cp -R "$APP_BUNDLE" "$DEST_DIR/"

echo "==> Launching $APP_NAME..."
open "$DEST_DIR/$APP_NAME.app"

echo ""
echo "✓ $APP_NAME built and launched successfully."
echo "  App location: $DEST_DIR/$APP_NAME.app"
