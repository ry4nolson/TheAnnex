import type { MetaFunction } from "react-router";
import { Tag, Plus, Wrench, RefreshCw } from "lucide-react";

export const meta: MetaFunction = () => [
  { title: "Changelog — The Annex" },
  {
    name: "description",
    content: "Release history and version notes for The Annex.",
  },
];

interface ChangelogEntry {
  version: string;
  date: string;
  sections: { type: string; items: string[] }[];
}

function parseChangelog(raw: string): ChangelogEntry[] {
  const entries: ChangelogEntry[] = [];
  let current: ChangelogEntry | null = null;
  let currentSection: { type: string; items: string[] } | null = null;

  for (const line of raw.split("\n")) {
    const versionMatch = line.match(
      /^## \[(\d+\.\d+\.\d+)\]\s*-\s*(\d{4}-\d{2}-\d{2})/
    );
    if (versionMatch) {
      if (current) entries.push(current);
      current = {
        version: versionMatch[1],
        date: versionMatch[2],
        sections: [],
      };
      currentSection = null;
      continue;
    }

    const sectionMatch = line.match(/^### (Added|Fixed|Changed)/);
    if (sectionMatch && current) {
      currentSection = { type: sectionMatch[1], items: [] };
      current.sections.push(currentSection);
      continue;
    }

    if (line.startsWith("- ") && currentSection) {
      currentSection.items.push(line.slice(2));
    }
  }

  if (current) entries.push(current);
  return entries;
}

function SectionBadge({ type }: { type: string }) {
  const config: Record<string, { color: string; icon: typeof Plus }> = {
    Added: { color: "bg-emerald-500/10 text-emerald-400", icon: Plus },
    Fixed: { color: "bg-amber-500/10 text-amber-400", icon: Wrench },
    Changed: { color: "bg-sky-500/10 text-sky-400", icon: RefreshCw },
  };

  const { color, icon: Icon } = config[type] ?? {
    color: "bg-brand-accent/10 text-brand-accent-light",
    icon: Tag,
  };

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold ${color}`}
    >
      <Icon size={12} />
      {type}
    </span>
  );
}

function formatItem(text: string) {
  return text.replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>");
}

const CHANGELOG_RAW = `## [1.11.0] - 2026-03-16
## [1.10.0] - 2026-03-16

### Fixed
- **Command injection via shell interpolation** — all shell commands now use Process with arguments array (runDirect/runDirectAsync) instead of string interpolation through bash -c, eliminating injection risk in hostnames, paths, share names, and custom rsync flags
- **SyncJob mutations off main thread** — rsync completion handler now wraps all @Published property updates in DispatchQueue.main.async to prevent SwiftUI data races
- **Thread-unsafe line buffer in ShellHelper** — lineBuffer in readabilityHandler is now protected by a dedicated bufferLock
- **processQueue TOCTOU race** — SyncEngine.processQueue() now collects all folders to start under a single lock acquisition instead of unlocking/relocking between iterations
- **SMB mounts not using stored credentials** — NASMonitor now retrieves passwords from Keychain via authenticatedShareURL(for:) and includes them in mount commands
- **Force unwraps on timers and AppDelegate properties** — timer!, syncTimer!, statusItem!, and menu! replaced with safe optional unwrapping
- **Silent data loss on decode failures** — all AppState load/save methods now log errors via NSLog instead of silently swallowing try? failures
- **Dead code in NASMonitor** — removed no-op expression
- **DiscoveredNAS deduplication broken** — hash(into:) and == now use hostname instead of per-instance UUID
- **Stale connection quality when NAS goes offline** — legacy fields are now cleared alongside per-device dictionaries
- **Process returned before started in ShellHelper.runAsync** — process is now started synchronously before returning
- **IOKit nil safety** — IOPSCopyPowerSourcesInfo() and IOPSCopyPowerSourcesList() return values are now nil-checked
- **Keychain save failures silently ignored** — failed saves now log an error to the activity log
- **Log export failures invisible to user** — export success/failure now logged to activity log

### Added
- **Shell escaping utility** — ShellHelper.shellEscape() for safe single-quote escaping, plus runDirect() and runDirectAsync() methods
- **Input validation** — hostname validation, bandwidth limit clamping, dangerous rsync flags stripped
- **Accessibility labels** — status icons, pickers, toggles, and menu bar icon now have proper VoiceOver descriptions

## [1.9.0] - 2026-03-13

### Changed
- **Sync History chart** — added time range picker and interval picker with proper time-bucketed aggregation and adaptive x-axis labels

## [1.8.0] - 2026-03-13

### Added
- **DMG installer** — releases now include a styled .dmg with custom background, app icon, and Applications drop link

## [1.7.1] - 2026-03-12

### Fixed
- **Duplicate permission dialogs on launch** — limits to 1 concurrent sync until first success, guards reconnect path against queuing
- **CI test failure for runAsync output** — drains remaining pipe data after waitUntilExit()

## [1.7.0] - 2026-03-12

### Fixed
- **Statistics reset on every restart** — SyncEngine now reads/writes directly from AppState.shared.statistics
- **Rsync stats never parsed** — ShellHelper.runAsync now accumulates and passes through all output
- **@Published mutations off main thread** — added internal backing stores with main-thread-only @Published updates
- **Sync counter could go negative** — clamped to max(0, n-1)
- **Shell command deadlock risk** — reversed pipe read and waitUntilExit order
- **Menu bar rebuilt on every log line** — removed redundant buildMenu() calls
- **Clear Logs didn't persist or update UI** — now calls saveActivityLog() and objectWillChange.send()

### Added
- **WiFi network restriction** — auto-sync skips when not connected to an allowed WiFi network
- **AC power restriction** — auto-sync skips when running on battery
- **Custom rsync flags** — user-defined rsync flags passed through to rsync
- **Launch at Login** — uses SMAppService (macOS 13+)

### Changed
- **Advanced settings fully persist** — WiFi filter, allowed SSIDs, AC power, and custom rsync flags save to UserDefaults
- **Removed dead code** — stripped unused SyncSchedule and FileFilters
- **Test suite updated** — added 7 regression tests

## [1.6.1] - 2026-03-12

### Fixed
- **CI build failure** — ChangelogView.swift and CHANGELOG.md resource copy were missing from CI workflows
- **Compiler warnings** — suppressed unused variable warnings

## [1.6.0] - 2026-03-12

### Added
- **What's New tab** — in-app changelog viewer with collapsible version headers and color-coded section badges

## [1.5.1] - 2026-03-12

### Changed
- **"Check for Update" opens release page** — now opens GitHub release page instead of directly downloading

## [1.5.0] - 2026-03-12

### Fixed
- **Auto-sync was never running** — added syncTimer to AppDelegate

## [1.4.0] - 2026-03-12

### Added
- **Symlink mode on folder creation** — toggle symlink mode when adding a new sync folder
- **Startup state verification** — verifies symlink state matches the actual filesystem on launch
- **Safe folder deletion** — removing a symlinked folder will unsymlink it first

## [1.3.0] - 2026-03-12

### Added
- **Symlink mode for macOS-protected folders** — automatically detected and run in sync-only mode
- **Clickable folder paths** — local and NAS paths open in Finder when clicked
- **Browse buttons** — folder picker dialogs for both paths
- **Startup recovery** — folders stuck in "Transitioning..." are recovered on launch
- **Update checker** — automatic check for new versions on startup

### Fixed
- **App hang after overnight sleep** — batched addLog() with 500ms coalescing
- **App hang on Cancel** — moved log() and process termination to background threads
- **Sync restart after cancel** — cancelling no longer re-queues the folder
- **Update alert not showing** — fixed race condition

### Changed
- "Pause" replaced with "Cancel" throughout
- About view and README updated

## [1.2.1] - 2026-03-12

### Fixed
- Update checker race condition — callback now fires after properties are set
- Startup update alert visibility — added delay and NSApp.activate

## [1.2.0] - 2026-03-12

### Added
- **Check for Updates** — queries GitHub Releases API
- **Startup update prompt** — alert on launch for newer versions
- **Manual update check** — button in About tab
- **Menu bar cancel** — individual sync jobs cancellable from menu bar

### Changed
- Rsync output processing batched for better performance
- rawLog changed from @Published to manual refresh
- ShellHelper.runAsync rewritten to use terminationHandler

## [1.1.0] - 2026-03-11

### Added
- **Symlink mode** — replace local folders with symlinks to NAS
- **Automatic unsymlink on NAS offline** — local copies restored
- **Automatic re-symlink on NAS online** — changes synced and symlinks re-created
- Raw rsync output toggle in sync detail view

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
- CI/CD with GitHub Actions`;

const entries = parseChangelog(CHANGELOG_RAW);

export default function Changelog() {
  return (
    <>
      <section className="border-b border-white/5 py-16">
        <div className="mx-auto max-w-4xl px-4 text-center sm:px-6">
          <span className="section-badge">Release History</span>
          <h1 className="section-heading mt-4 text-white">Changelog</h1>
          <p className="mt-4 text-brand-400">
            All notable changes to The Annex, organized by version.
          </p>
        </div>
      </section>

      <section className="py-16">
        <div className="mx-auto max-w-4xl px-4 sm:px-6">
          <div className="space-y-12">
            {entries.map((entry) => (
              <article
                key={entry.version}
                className="rounded-2xl border border-white/5 bg-white/[0.02] p-6 sm:p-8"
              >
                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-2">
                    <Tag size={16} className="text-brand-accent-light" />
                    <h2 className="font-display text-xl font-bold text-white">
                      v{entry.version}
                    </h2>
                  </div>
                  <time
                    dateTime={entry.date}
                    className="text-sm text-brand-500"
                  >
                    {new Date(entry.date + "T00:00:00").toLocaleDateString(
                      "en-US",
                      {
                        year: "numeric",
                        month: "long",
                        day: "numeric",
                      }
                    )}
                  </time>
                </div>

                {entry.sections.map((section, si) => (
                  <div key={si} className="mt-6">
                    <SectionBadge type={section.type} />
                    <ul className="mt-3 space-y-2">
                      {section.items.map((item, ii) => (
                        <li
                          key={ii}
                          className="pl-4 text-sm leading-relaxed text-brand-300 before:absolute before:left-0 before:text-brand-600 before:content-['•'] relative"
                        >
                          <span
                            dangerouslySetInnerHTML={{
                              __html: formatItem(item),
                            }}
                          />
                        </li>
                      ))}
                    </ul>
                  </div>
                ))}
              </article>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
