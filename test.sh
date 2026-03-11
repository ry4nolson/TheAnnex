#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/tests"
TEST_BINARY="$BUILD_DIR/TheAnnexTests"

echo "==> Compiling tests..."
mkdir -p "$BUILD_DIR"

# Source files (models, utilities, controllers — no Views or main.swift)
SOURCE_FILES=(
    "$SCRIPT_DIR/Models/NASState.swift"
    "$SCRIPT_DIR/Models/NASDevice.swift"
    "$SCRIPT_DIR/Models/SyncFolder.swift"
    "$SCRIPT_DIR/Models/SyncJob.swift"
    "$SCRIPT_DIR/Models/ActivityEntry.swift"
    "$SCRIPT_DIR/Models/Statistics.swift"
    "$SCRIPT_DIR/Utilities/ShellHelper.swift"
    "$SCRIPT_DIR/Utilities/RsyncWrapper.swift"
    "$SCRIPT_DIR/Utilities/NetworkDetector.swift"
    "$SCRIPT_DIR/Utilities/NASDiscovery.swift"
    "$SCRIPT_DIR/Utilities/KeychainHelper.swift"
    "$SCRIPT_DIR/Utilities/AnnexQuotes.swift"
    "$SCRIPT_DIR/Utilities/SymlinkManager.swift"
    "$SCRIPT_DIR/Utilities/UpdateChecker.swift"
    "$SCRIPT_DIR/Controllers/AppState.swift"
    "$SCRIPT_DIR/Controllers/SyncEngine.swift"
    "$SCRIPT_DIR/Controllers/NASMonitor.swift"
    "$SCRIPT_DIR/Tests/TheAnnexTests.swift"
)

swiftc \
    "${SOURCE_FILES[@]}" \
    -o "$TEST_BINARY" \
    -framework Cocoa \
    -framework UserNotifications \
    -framework Combine \
    -framework CoreWLAN \
    -framework IOKit \
    -framework Security \
    -framework Network \
    -framework UniformTypeIdentifiers

echo "==> Running tests..."
"$TEST_BINARY"
