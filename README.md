# The Annex

A macOS menu bar app that quietly syncs your Mac's folders to your NAS — so everything feels local, even when it's not.

## Installation

### Download

Grab the latest `TheAnnex.zip` from [GitHub Releases](../../releases), unzip, and drag to `~/Applications`.

### Build from Source

```bash
git clone <repo-url>
cd TheAnnex
./build.sh
```

The app will be installed to `~/Applications/TheAnnex.app` and launched automatically.

### Requirements

- macOS 12.0 (Monterey) or later
- Xcode Command Line Tools (build from source only)
- Access to a NAS with SMB shares

## Features

### Multi-NAS Support
- Configure unlimited NAS devices with per-device credentials
- Bonjour/mDNS network discovery — automatically finds any NAS advertising SMB
- Set a default NAS; assign individual sync folders to specific devices
- Per-device monitoring: online status, connection quality, disk space

### Sync Engine
- Queue-based sync with concurrent support (max 2 simultaneous)
- One-way sync: Local → NAS (authoritative backup model)
- Pause/resume all syncs
- Per-folder sync on demand or sync all at once
- Rsync integration with progress tracking and bandwidth throttling
- Editable local and NAS paths per sync folder

### Monitoring
- Live connection quality (latency, packet loss) per NAS
- Disk space monitoring with progress bars
- Auto-mount SMB shares when NAS comes online
- Configurable check intervals (30s to 30min)
- Real-time updates on the General settings tab

### User Interface
- **General** — NAS devices, network discovery, monitoring dashboard, startup options
- **Sync Folders** — Visual list of sync pairs with status, add/edit/delete, browse paths
- **Activity Log** — Searchable, filterable log with export
- **Statistics** — Transfer metrics, success rates, charts (macOS 13+)
- **Advanced** — Bandwidth limits, WiFi filtering, power management, personality mode, custom rsync flags
- **About** — Version info (read from bundle), app icon

### Menu Bar
- Dynamic status icon (connected/offline/syncing)
- Quick access to sync folders and shares
- Active sync progress
- Recent activity feed
- Pause/resume controls

### Security
- Keychain integration for NAS passwords (per-device)
- Ad-hoc code signing for macOS permission persistence

### Personality
- Optional "Annex personality" mode with fun quotes in notifications, logs, and empty states
- Toggle on/off in Advanced settings

## Getting Started

1. Launch The Annex — it appears in your menu bar
2. The welcome screen walks you through first-time setup
3. In **General**, click **Add NAS** → **Scan Network** to auto-discover your NAS
4. Enter credentials and shares, click **Add**
5. Go to **Sync Folders** → **Add Folder** → pick a preset or custom folder
6. Click **Sync All** or let the automatic check interval handle it

## Releasing

CI runs on every push to `main`. Releases are triggered by version tags.

### Creating a Release

```bash
./release.sh patch   # 1.0.0 → 1.0.1
./release.sh minor   # 1.0.1 → 1.1.0
./release.sh major   # 1.1.0 → 2.0.0
```

This bumps the version in `Info.plist`, commits, tags, and pushes. GitHub Actions builds the app and publishes `TheAnnex.zip` to Releases automatically.

## Architecture

```
TheAnnex/
├── main.swift                          # Entry point
├── build.sh                            # Local build script
├── release.sh                          # Semver bump + tag + push
├── Info.plist                          # App metadata & version
├── AppIcon.appiconset/                 # App icon assets
├── Models/
│   ├── NASState.swift
│   ├── NASDevice.swift
│   ├── SyncFolder.swift
│   ├── SyncJob.swift
│   ├── ActivityEntry.swift
│   └── Statistics.swift
├── Controllers/
│   ├── AppDelegate.swift
│   ├── AppState.swift
│   ├── MainWindowController.swift
│   ├── SyncEngine.swift
│   └── NASMonitor.swift
├── Views/
│   ├── GeneralSettingsView.swift
│   ├── SyncFoldersView.swift
│   ├── ActivityLogView.swift
│   ├── StatisticsView.swift
│   ├── AdvancedSettingsView.swift
│   └── AboutView.swift
├── Utilities/
│   ├── ShellHelper.swift
│   ├── RsyncWrapper.swift
│   ├── NetworkDetector.swift
│   ├── NASDiscovery.swift
│   ├── KeychainHelper.swift
│   └── AnnexQuotes.swift
└── .github/workflows/
    ├── ci.yml                          # Build on push/PR to main
    └── release.yml                     # Build + publish on version tags
```

### Key Technologies

- **SwiftUI** — UI framework
- **Combine** — Reactive state management
- **Network.framework** — Bonjour/mDNS NAS discovery
- **Rsync** — File synchronization
- **CoreWLAN** — WiFi network detection
- **IOKit** — Power state detection
- **Security.framework** — Keychain credential storage

## Troubleshooting

### NAS Won't Connect
1. Verify hostname: `ping YourNAS.local`
2. Check credentials
3. Ensure SMB is enabled on the NAS

### Sync Fails
1. Check the **Activity Log** for errors
2. Verify NAS paths exist and are writable
3. Ensure sufficient disk space

### Shares Won't Mount
1. Try mounting manually in Finder: `smb://YourNAS.local/share`
2. Check firewall settings
3. Review Activity Log for mount errors

### NAS Not Found in Scan
1. Ensure your NAS advertises SMB via Bonjour/mDNS
2. Check that both devices are on the same network/subnet
3. Try entering the hostname manually

## License

GPL-3.0 — free to use, modify, and share. Derivative works must remain open source. See [LICENSE](LICENSE) for details.
