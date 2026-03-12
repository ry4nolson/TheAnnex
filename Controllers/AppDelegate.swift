import Cocoa
import UserNotifications
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var mainWindowController = MainWindowController()
    
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        requestNotificationPermission()
        setupStatusItem()
        
        setupObservers()
        
        SyncEngine.shared.onLog = { [weak self] entry in
            AppState.shared.addLog(entry)
            DispatchQueue.main.async {
                self?.buildMenu()
            }
        }
        
        NASMonitor.shared.onLog = { entry in
            AppState.shared.addLog(entry)
        }
        
        NASMonitor.shared.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.updateIcon()
                self?.buildMenu()
            }
            
            if state == .connected {
                self?.sendNotification(title: "The Annex", body: "Connected to NAS")
                
                // Symlink mode: sync any new local files, then re-symlink
                DispatchQueue.global(qos: .userInitiated).async {
                    let folders = AppState.shared.syncFolders.filter { $0.symlinkMode && $0.symlinkState == .local && $0.isEnabled }
                    for folder in folders {
                        AppState.shared.addLog(ActivityEntry(level: .info, category: .sync, message: "NAS online — syncing \(folder.name) before re-symlinking"))
                        SyncEngine.shared.queueSync(for: folder)
                    }
                }
            } else if state == .offline {
                let body = AnnexQuotes.shared.quote(AnnexQuotes.nasOffline) ?? "NAS is offline"
                self?.sendNotification(title: "The Annex", body: body)
                
                // Symlink mode: unsymlink all symlinked folders so files save locally
                DispatchQueue.global(qos: .userInitiated).async {
                    let folders = AppState.shared.syncFolders
                    let results = SymlinkManager.shared.handleNASOffline(folders: folders)
                    
                    for (folder, result) in results {
                        switch result {
                        case .success:
                            AppState.shared.addLog(ActivityEntry(level: .info, category: .sync, message: "Unsymlinked \(folder.name) — files will save locally"))
                            if var updated = AppState.shared.syncFolders.first(where: { $0.id == folder.id }) {
                                updated.symlinkState = .local
                                DispatchQueue.main.async {
                                    AppState.shared.updateSyncFolder(updated)
                                }
                            }
                        case .failure(let error):
                            AppState.shared.addLog(ActivityEntry(level: .error, category: .sync, message: "Failed to unsymlink \(folder.name): \(error)"))
                        }
                    }
                }
            }
        }
        
        NASMonitor.shared.startMonitoring(interval: AppState.shared.checkInterval)
        startSyncTimer()
        
        AppState.shared.addLog(ActivityEntry(
            level: .info,
            category: .system,
            message: "The Annex started — auto-sync every \(Int(AppState.shared.checkInterval))s"
        ))
        
        mainWindowController.showWindow()
        
        // Startup recovery (runs on background thread after UI is visible)
        DispatchQueue.global(qos: .utility).async {
            for folder in AppState.shared.syncFolders {
                var updated = folder
                var changed = false
                
                // Verify symlink state matches actual filesystem
                let actuallySymlinked = SymlinkManager.shared.isSymlink(at: folder.localPath)
                
                if folder.symlinkState == .symlinked && !actuallySymlinked {
                    updated.symlinkState = .local
                    changed = true
                    AppState.shared.addLog(ActivityEntry(level: .info, category: .sync, message: "\(folder.name) is no longer symlinked on disk — updated state to local"))
                } else if folder.symlinkState == .restoring {
                    updated.symlinkState = actuallySymlinked ? .symlinked : .local
                    changed = true
                    AppState.shared.addLog(ActivityEntry(level: .info, category: .sync, message: "Recovered \(folder.name) from stuck transitioning state → \(updated.symlinkState.rawValue)"))
                }
                
                // Migrate: detect folders that were auto-disabled due to macOS protection
                if !folder.symlinkMode && !folder.symlinkProtected && folder.symlinkState == .local && !SymlinkManager.shared.isSymlink(at: folder.localPath) {
                    let home = NSHomeDirectory()
                    let protectedPaths = [home + "/Desktop", home + "/Pictures", home + "/Documents", home + "/Music", home + "/Movies"]
                    if protectedPaths.contains(folder.localPath) {
                        updated.symlinkProtected = true
                        changed = true
                    }
                }
                
                if changed {
                    DispatchQueue.main.async {
                        AppState.shared.updateSyncFolder(updated)
                    }
                }
            }
        }
        
        // Check for updates on startup (slight delay so window is visible)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UpdateChecker.shared.checkForUpdates { hasUpdate in
                if hasUpdate, let latest = UpdateChecker.shared.latestVersion {
                    NSApp.activate(ignoringOtherApps: true)
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "The Annex v\(latest) is available. You're running v\(UpdateChecker.shared.currentVersion)."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "View Release")
                    alert.addButton(withTitle: "Later")
                    
                    if alert.runModal() == .alertFirstButtonReturn {
                        UpdateChecker.shared.openReleasePage()
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        syncTimer?.invalidate()
        NASMonitor.shared.stopMonitoring()
    }
    
    // MARK: - Auto-Sync Timer
    
    private func startSyncTimer() {
        let interval = AppState.shared.checkInterval
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.autoSync()
        }
        RunLoop.main.add(syncTimer!, forMode: .common)
    }
    
    func restartSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
        startSyncTimer()
        let interval = Int(AppState.shared.checkInterval)
        AppState.shared.addLog(ActivityEntry(level: .info, category: .system, message: "Sync interval updated to \(interval)s"))
    }
    
    private func autoSync() {
        // Only sync when NAS is online and no syncs are already running
        guard NASMonitor.shared.currentState != .offline else { return }
        guard SyncEngine.shared.activeSyncJobs.isEmpty else { return }
        
        let enabledFolders = AppState.shared.syncFolders.filter { $0.isEnabled }
        guard !enabledFolders.isEmpty else { return }
        
        AppState.shared.addLog(ActivityEntry(level: .info, category: .sync, message: "Auto-sync triggered for \(enabledFolders.count) folder(s)"))
        SyncEngine.shared.queueSyncAll(folders: enabledFolders)
    }
    
    private func setupObservers() {
        AppState.shared.$syncFolders
            .sink { [weak self] _ in
                self?.buildMenu()
            }
            .store(in: &cancellables)
        
        SyncEngine.shared.$activeSyncJobs
            .sink { [weak self] jobs in
                if !jobs.isEmpty {
                    NASMonitor.shared.currentState = .syncing
                } else if NASMonitor.shared.currentState == .syncing {
                    NASMonitor.shared.currentState = .connected
                }
                self?.updateIcon()
                self?.buildMenu()
            }
            .store(in: &cancellables)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()
        statusItem.menu = menu
    }
    
    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let state = NASMonitor.shared.currentState
        
        if let image = NSImage(systemSymbolName: state.iconName, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
        }
    }
    
    private func buildMenu() {
        menu = NSMenu()
        
        let state = NASMonitor.shared.currentState
        let stateItem = NSMenuItem()
        stateItem.title = "Status: \(state.displayName)"
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        
        if !AppState.shared.nasDevices.isEmpty {
            let nasCount = AppState.shared.nasDevices.count
            let nasItem = NSMenuItem()
            nasItem.title = "\(nasCount) NAS device\(nasCount == 1 ? "" : "s") configured"
            nasItem.isEnabled = false
            menu.addItem(nasItem)
        }
        
        if let quality = NASMonitor.shared.connectionQuality {
            let qualityItem = NSMenuItem()
            qualityItem.title = "Connection: \(quality.qualityLevel.rawValue)"
            qualityItem.isEnabled = false
            menu.addItem(qualityItem)
        }
        
        if let diskSpace = NASMonitor.shared.nasDiskSpace {
            let diskItem = NSMenuItem()
            diskItem.title = "NAS: \(diskSpace.freeFormatted) free"
            diskItem.isEnabled = false
            menu.addItem(diskItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let openItem = NSMenuItem(title: "Open The Annex", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        if !AppState.shared.syncFolders.isEmpty {
            let syncFoldersMenu = NSMenu()
            
            for folder in AppState.shared.syncFolders.prefix(10) {
                let folderItem = NSMenuItem(title: folder.name, action: #selector(syncFolder(_:)), keyEquivalent: "")
                folderItem.target = self
                folderItem.representedObject = folder.id
                folderItem.isEnabled = folder.isEnabled
                
                if let lastSync = folder.lastSyncDate {
                    folderItem.toolTip = "Last synced: \(lastSync.formatted())"
                }
                
                syncFoldersMenu.addItem(folderItem)
            }
            
            let foldersMenuItem = NSMenuItem(title: "Sync Folder", action: nil, keyEquivalent: "")
            foldersMenuItem.submenu = syncFoldersMenu
            menu.addItem(foldersMenuItem)
            
            let syncAllItem = NSMenuItem(title: "Sync All Folders", action: #selector(syncAllFolders), keyEquivalent: "")
            syncAllItem.target = self
            menu.addItem(syncAllItem)
        }
        
        if !SyncEngine.shared.activeSyncJobs.isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            let activeItem = NSMenuItem()
            activeItem.title = "Active Syncs (\(SyncEngine.shared.activeSyncJobs.count))"
            activeItem.isEnabled = false
            menu.addItem(activeItem)
            
            for job in SyncEngine.shared.activeSyncJobs.prefix(3) {
                let jobItem = NSMenuItem()
                jobItem.title = "  \(job.folderName) - \(job.filesTransferred) files"
                let jobSubMenu = NSMenu()
                let cancelJobItem = NSMenuItem(title: "Cancel", action: #selector(cancelSyncJob(_:)), keyEquivalent: "")
                cancelJobItem.target = self
                cancelJobItem.representedObject = job.id
                jobSubMenu.addItem(cancelJobItem)
                jobItem.submenu = jobSubMenu
                menu.addItem(jobItem)
            }
            
            let cancelItem = NSMenuItem(title: "Cancel All Syncs", action: #selector(cancelSyncs), keyEquivalent: "")
            cancelItem.target = self
            menu.addItem(cancelItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        if !AppState.shared.nasDevices.isEmpty {
            let sharesMenu = NSMenu()
            for device in AppState.shared.nasDevices {
                for share in device.shares {
                    let shareItem = NSMenuItem(title: "\(device.name)/\(share)", action: #selector(openShare(_:)), keyEquivalent: "")
                    shareItem.target = self
                    shareItem.representedObject = share
                    sharesMenu.addItem(shareItem)
                }
            }
            if sharesMenu.items.isEmpty {
                let emptyItem = NSMenuItem(title: "No shares configured", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                sharesMenu.addItem(emptyItem)
            }
            let sharesMenuItem = NSMenuItem(title: "Open Share", action: nil, keyEquivalent: "")
            sharesMenuItem.submenu = sharesMenu
            menu.addItem(sharesMenuItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let recentItem = NSMenuItem(title: "Recent Activity", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu()
        let recentLogs = AppState.shared.activityLog.suffix(5).reversed()
        
        if recentLogs.isEmpty {
            let emptyItem = NSMenuItem(title: "No activity yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            recentMenu.addItem(emptyItem)
        } else {
            for entry in recentLogs {
                let logItem = NSMenuItem(
                    title: "\(entry.formattedTimestamp)  \(entry.message)",
                    action: nil,
                    keyEquivalent: ""
                )
                logItem.isEnabled = false
                recentMenu.addItem(logItem)
            }
        }
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func openMainWindow() {
        mainWindowController.showWindow()
    }
    
    @objc private func syncFolder(_ sender: NSMenuItem) {
        guard let folderId = sender.representedObject as? UUID,
              let folder = AppState.shared.syncFolders.first(where: { $0.id == folderId }) else {
            return
        }
        SyncEngine.shared.queueSync(for: folder)
    }
    
    @objc private func syncAllFolders() {
        SyncEngine.shared.queueSyncAll(folders: AppState.shared.syncFolders)
    }
    
    @objc private func cancelSyncs() {
        SyncEngine.shared.cancelAll()
    }
    
    @objc private func cancelSyncJob(_ sender: NSMenuItem) {
        guard let jobId = sender.representedObject as? UUID else { return }
        SyncEngine.shared.cancelSync(jobId: jobId)
    }
    
    @objc private func openShare(_ sender: NSMenuItem) {
        guard let share = sender.representedObject as? String else { return }
        let path = "/Volumes/\(share)"
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
