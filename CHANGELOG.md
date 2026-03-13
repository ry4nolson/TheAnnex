# Changelog

All notable changes to The Annex will be documented in this file.





## [Unreleased]
## [1.7.0] - 2026-03-12

### Fixed
- **Statistics reset on every restart** — `SyncEngine` had its own `Statistics()` initialized to zero, overwriting persisted stats on first sync. Now reads/writes directly from `AppState.shared.statistics`
- **Rsync stats never parsed** — `ShellHelper.runAsync` returned empty output in completion, so rsync `--stats` summary was lost. Now accumulates and passes through all output
- **@Published mutations off main thread** — `SyncEngine.syncQueue` and `activeSyncJobs` were mutated from background threads, risking SwiftUI crashes. Added internal backing stores with main-thread-only `@Published` updates
- **Sync counter could go negative** — `cancelAll` zeroed `currentSyncs` but in-flight completions still decremented. Clamped to `max(0, n-1)`
- **Shell command deadlock risk** — `ShellHelper.run` called `waitUntilExit()` before reading pipe data, risking deadlock on large output. Reversed order
- **Menu bar rebuilt on every log line** — `SyncEngine.onLog` triggered `buildMenu()` per log entry during syncs. Removed; menu already rebuilds via `activeSyncJobs` observer
- **Clear Logs didn't persist or update UI** — `clearLogs()` now calls `saveActivityLog()` and `objectWillChange.send()`

### Added
- **WiFi network restriction** — auto-sync skips when not connected to an allowed WiFi network (configurable in Advanced settings)
- **AC power restriction** — auto-sync skips when running on battery (configurable in Advanced settings)
- **Custom rsync flags** — user-defined rsync flags from Advanced settings are now passed through to rsync
- **Launch at Login** — uses `SMAppService` (macOS 13+) for real login item registration

### Changed
- **Advanced settings fully persist** — WiFi filter, allowed SSIDs, AC power, and custom rsync flags now save to UserDefaults and reload on launch
- **Removed dead code** — stripped unused `SyncSchedule` and `FileFilters` structs and properties from `SyncFolder`
- **Test suite updated** — removed obsolete `SyncSchedule`/`FileFilters` tests, added 7 regression tests: statistics persistence, SyncEngine no-own-stats, runAsync output accumulation, large-output pipe safety, clearLogs persistence, advanced settings persistence, SyncFolder backward compatibility with old serialized data

## [1.6.1] - 2026-03-12

### Fixed
- **CI build failure** — `ChangelogView.swift` and `CHANGELOG.md` resource copy were missing from `ci.yml` and `release.yml` GitHub Actions workflows
- **Compiler warnings** — suppressed unused variable warnings in `NASDiscovery.swift` and `NASMonitor.swift`

## [1.6.0] - 2026-03-12

### Added
- **What's New tab** — in-app changelog viewer that parses `CHANGELOG.md` with collapsible version headers, color-coded section badges (Added/Fixed/Changed), and bold text rendering

## [1.5.1] - 2026-03-12

### Changed
- **"Check for Update" opens release page** — the update button in About now says "View Release" and opens the GitHub release page (with notes) instead of directly downloading the zip file

## [1.5.0] - 2026-03-12

### Fixed
- **Auto-sync was never running** — periodic sync timer was missing entirely. `NASMonitor` only performed health checks but never triggered syncs. Added `syncTimer` to `AppDelegate` that fires on the configured check interval, syncing all enabled folders when the NAS is online and no syncs are active

## [1.4.0] - 2026-03-12

### Added
- **Symlink mode on folder creation** — toggle symlink mode when adding a new sync folder (preset or custom). Automatically disabled with explanation for macOS-protected folders
- **Startup state verification** — on launch, verifies symlink state matches the actual filesystem (e.g. if a symlink was removed manually, state is corrected to "local")
- **Safe folder deletion** — removing a sync folder that is currently symlinked will unsymlink it first, restoring the local copy. If unsymlink fails, the folder record is preserved and an error is shown

## [1.3.0] - 2026-03-12

### Added
- **Symlink mode for macOS-protected folders** — folders like Desktop, Pictures, and Documents that macOS prevents from being symlinked are now automatically detected and run in sync-only mode with a clear "Sync only (macOS protected)" label
- **Clickable folder paths** — local and NAS paths in the sync folder list now open in Finder when clicked
- **Browse buttons** — folder picker dialogs for both Local Path and NAS Path fields when adding or editing custom sync folders, with "New Folder" support
- **Startup recovery** — folders stuck in "Transitioning..." state from a crash or hang are automatically recovered on next launch
- **Update checker** — automatic check for new versions on startup with a prompt to view the latest release

### Fixed
- **App hang after overnight sleep** — `addLog()` was flooding the main thread with `@Published` array mutations and `UserDefaults` writes on every log entry. Now batched with 500ms coalescing and thread-safe via `NSLock`
- **App hang on Cancel** — moved `log()` calls and process termination in cancel paths to background threads to prevent blocking the main thread
- **Sync restart after cancel** — cancelling a sync no longer triggers an immediate re-queue of the same folder
- **Update alert not showing** — fixed a race condition where `latestVersion` was nil when the completion handler fired

### Changed
- "Pause" replaced with "Cancel" throughout — the previous pause was actually killing the rsync process, so the UI now honestly reflects that
- About view features list updated to reflect current functionality
- README updated with symlink mode documentation, architecture changes, and accurate feature descriptions

## [1.2.1] - 2026-03-12

### Fixed
- Update checker race condition — completion callback now fires after properties are set on the main thread
- Startup update alert visibility — added delay and `NSApp.activate` to ensure the alert appears in front of permission dialogs

## [1.2.0] - 2026-03-12

### Added
- **Check for Updates** — new `UpdateChecker` utility that queries GitHub Releases API
- **Startup update prompt** — alert on launch when a newer version is available, with "View Release" button
- **Manual update check** — "Check for Updates" button in the About tab
- **Menu bar cancel** — individual sync jobs can be cancelled from the menu bar submenu

### Changed
- Rsync output processing batched for better performance — `rawOutputHandler` now receives `[String]` batches instead of individual lines
- `rawLog` on `SyncJob` changed from `@Published` to manual refresh to avoid SwiftUI diffing overhead
- `ShellHelper.runAsync` rewritten to use `terminationHandler` instead of `waitUntilExit` to prevent deadlocks

## [1.1.0] - 2026-03-11

### Added
- **Symlink mode** — after syncing, replace local folders with symlinks to the NAS so apps read/write directly to network storage
- **Automatic unsymlink on NAS offline** — symlinks are removed and local copies restored when the NAS goes offline
- **Automatic re-symlink on NAS online** — local changes are synced and symlinks re-created when the NAS comes back
- Raw rsync output toggle in the sync detail view

### Changed
- Rsync output display now shows "Skip existing" messages cleanly

## [1.0.0] - 2026-03-11

### Added
- Initial release
- Multi-NAS support with Bonjour/mDNS network discovery
- Queue-based sync engine with rsync integration (max 2 concurrent)
- One-way sync: Local to NAS with progress tracking
- Live NAS monitoring — connection quality, latency, disk space
- Auto-mount SMB shares when NAS comes online
- Configurable check intervals (30s to 30min)
- SwiftUI interface with General, Sync Folders, Activity Log, Statistics, Advanced, and About tabs
- Menu bar app with dynamic status icon
- Keychain integration for NAS credentials
- Bandwidth throttling and WiFi/power-based sync scheduling
- Preset folder configurations (Downloads, Documents, Pictures, Movies, Music, Desktop)
- Custom folder support with exclude patterns
- Activity log with search and export
- Statistics dashboard with transfer metrics and charts (macOS 13+)
- Annex personality mode with fun quotes
- Ad-hoc code signing for permission persistence
- CI/CD with GitHub Actions — build on push, publish releases on version tags
- 174 assertions across 19 test suites
