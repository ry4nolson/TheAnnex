# NASManager 2.0

A powerful macOS menu bar application for syncing media folders between your Mac and NAS, creating a personal cloud sync system similar to Dropbox or Google Drive.

## Features

### ✅ Implemented (Phase 1 & 2)

#### Multi-Folder Sync Management
- Configure multiple sync pairs (Pictures, Movies, Documents, Downloads, Music, Desktop)
- One-way sync: Local → NAS (authoritative backup model)
- Per-folder enable/disable toggles
- Preset folder configurations for common media folders
- Custom folder support
- Exclude patterns (`.DS_Store`, `.Spotlight-V100`, temp files, etc.)
- Track last sync date per folder

#### Full Window Interface
- **General Tab**: NAS connection settings, check interval, launch at login
- **Sync Folders Tab**: Visual list of all sync pairs with status, add/edit/delete folders
- **Activity Log Tab**: Searchable, filterable activity log with export functionality
- **Statistics Tab**: Transfer metrics, sync history, success rates, charts (macOS 13+)
- **Advanced Tab**: Bandwidth controls, WiFi filtering, power management, connection quality
- **About Tab**: Version info, features list, documentation links

#### Enhanced Sync Engine
- Queue-based sync system with concurrent sync support (max 2 simultaneous)
- Progress tracking with file counts and bytes transferred
- Pause/resume all syncs functionality
- Individual folder sync on demand
- Rsync integration with progress callbacks
- Bandwidth throttling support

#### NAS Monitoring
- Automatic connectivity checks via ping
- Connection quality metrics (latency, packet loss)
- Disk space monitoring (NAS and local)
- Auto-mount SMB shares when NAS comes online
- Manual share mount/unmount controls
- State tracking (Connected, Offline, Syncing, Paused, Error)

#### Activity Logging & Statistics
- Comprehensive activity log (up to 1000 entries)
- Log levels: Debug, Info, Warning, Error
- Categories: Sync, Mount, Network, System, Error
- Search and filter capabilities
- Export logs to text file
- Sync history tracking with detailed metrics
- Success rate calculation
- Transfer speed tracking

#### Security
- Keychain integration for NAS password storage
- Secure credential management

#### User Experience
- Menu bar presence with dynamic status icons
- Recent activity in menu (last 5 entries)
- Quick access to sync folders from menu
- Active sync progress in menu
- Native macOS design with dark mode support
- Keyboard shortcuts throughout

### 🚧 Planned (Phase 3-5)

#### Smart Sync Features (Phase 3)
- WiFi network detection (sync only on specific networks)
- Scheduled sync windows (time-of-day controls)
- File type filters per folder
- Size-based sync rules
- AC power detection for laptops
- Dry-run preview mode

#### Advanced Monitoring (Phase 3)
- Share health checks (read/write tests)
- Alert thresholds for disk space
- Wake-on-LAN support

#### Performance Controls (Phase 4)
- Enhanced bandwidth throttling UI
- Queue management improvements
- Estimated time remaining for syncs
- Low-power mode

#### Polish & Power Features (Phase 5)
- Advanced error recovery with retry logic
- Diagnostic tools for troubleshooting
- Quick actions: Open in Finder, copy paths
- Custom rsync flags support
- Menu organization improvements

## Installation

### Build from Source

```bash
cd /Users/rolson/Developer/NASManager
./build.sh
```

The app will be installed to `~/Applications/NASManager.app` and launched automatically.

### Requirements

- macOS 12.0 (Monterey) or later
- Xcode Command Line Tools
- Swift 5.5+
- Access to a NAS with SMB shares

## Configuration

### First Launch

1. Click the NASManager icon in the menu bar
2. Select "Open NASManager" to open the main window
3. Go to the **General** tab:
   - Enter your NAS hostname (e.g., `RyaNAS.local`)
   - Enter your NAS username (e.g., `admin`)
   - Enter your NAS password (stored securely in Keychain)
   - List your SMB shares (comma-separated)
   - Set check interval
   - Enable "Launch at Login" if desired
4. Click "Save Settings"

### Adding Sync Folders

1. Go to the **Sync Folders** tab
2. Click "Add Folder"
3. Choose from preset folders (Pictures, Movies, Documents, etc.) or create a custom folder
4. Configure exclude patterns if needed
5. Click "Add"

### Manual Sync

- Click "Sync All" in the Sync Folders tab to sync all enabled folders
- Click the sync icon next to individual folders to sync just that folder
- Use the menu bar: "Sync Folder" → select folder name

## Architecture

### File Structure

```
NASManager/
├── main.swift                          # Entry point
├── Models/                             # Data models
│   ├── NASState.swift
│   ├── SyncFolder.swift
│   ├── SyncJob.swift
│   ├── ActivityEntry.swift
│   └── Statistics.swift
├── Controllers/                        # Business logic
│   ├── AppDelegate.swift
│   ├── AppState.swift
│   ├── MainWindowController.swift
│   ├── SyncEngine.swift
│   └── NASMonitor.swift
├── Views/                              # SwiftUI views
│   ├── GeneralSettingsView.swift
│   ├── SyncFoldersView.swift
│   ├── ActivityLogView.swift
│   ├── StatisticsView.swift
│   ├── AdvancedSettingsView.swift
│   └── AboutView.swift
├── Utilities/                          # Helper classes
│   ├── ShellHelper.swift
│   ├── RsyncWrapper.swift
│   ├── NetworkDetector.swift
│   └── KeychainHelper.swift
└── Resources/
    └── Info.plist
```

### Key Technologies

- **SwiftUI**: Modern UI framework for all views
- **Combine**: Reactive state management
- **Rsync**: File synchronization engine
- **CoreWLAN**: WiFi network detection
- **IOKit**: Power state detection
- **Keychain**: Secure credential storage

### Data Persistence

- **UserDefaults**: Settings and sync folder configurations
- **Keychain**: NAS credentials
- **In-Memory**: Activity log (1000 entries max)
- **Codable**: Statistics and sync history

## Usage Tips

### Exclude Patterns

Edit any sync folder to customize exclude patterns. Common patterns:
- `.DS_Store` - macOS metadata
- `.Spotlight-V100` - Spotlight index
- `*.tmp` - Temporary files
- `.localized` - Localization files

### Bandwidth Limiting

In the **Advanced** tab, set a bandwidth limit in KB/s to prevent saturating your network. Set to 0 for unlimited.

### Activity Log

- Search logs by keyword
- Filter by level (Debug, Info, Warning, Error)
- Filter by category (Sync, Mount, Network, System)
- Export logs for troubleshooting

### Statistics

View detailed sync history including:
- Total syncs performed
- Success rate percentage
- Total data transferred
- Files synced
- Historical charts (macOS 13+)

## Troubleshooting

### NAS Won't Connect

1. Check hostname is correct (try pinging from Terminal)
2. Verify username and password
3. Ensure SMB shares are enabled on NAS
4. Check network connectivity

### Sync Fails

1. Check Activity Log for detailed error messages
2. Verify NAS paths exist and are writable
3. Ensure sufficient disk space on NAS
4. Check exclude patterns aren't blocking files

### Shares Won't Mount

1. Verify SMB is enabled on NAS
2. Check firewall settings
3. Try mounting manually in Finder first
4. Review Activity Log for mount errors

## Future Enhancements

- Windows version (separate codebase)
- iOS companion app for monitoring
- Web interface for remote status
- Cloud backup integration
- Bidirectional sync option

## Version History

### 2.0.0 (2026-03-11)
- Complete rewrite with modular architecture
- Multi-folder sync support
- Full window interface with 6 tabs
- Enhanced monitoring and statistics
- Keychain integration
- SwiftUI-based modern UI

### 1.0.0 (Original)
- Basic Downloads folder sync
- Simple settings window
- Menu bar presence
- Auto-mount shares

## License

Personal use project for RyaNAS.

## Credits

Developed for personal cloud sync across multiple Macs using a central NAS as the storage hub.
