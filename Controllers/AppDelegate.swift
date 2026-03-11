import Cocoa
import UserNotifications
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var mainWindowController = MainWindowController()
    
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        requestNotificationPermission()
        setupStatusItem()
        
        setupObservers()
        
        SyncEngine.shared.onLog = { [weak self] entry in
            AppState.shared.addLog(entry)
            self?.buildMenu()
        }
        
        NASMonitor.shared.onLog = { entry in
            AppState.shared.addLog(entry)
        }
        
        NASMonitor.shared.onStateChange = { [weak self] state in
            self?.updateIcon()
            self?.buildMenu()
            
            if state == .connected {
                self?.sendNotification(title: "The Annex", body: "Connected to NAS")
            } else if state == .offline {
                let body = AnnexQuotes.shared.quote(AnnexQuotes.nasOffline) ?? "NAS is offline"
                self?.sendNotification(title: "The Annex", body: body)
            }
        }
        
        NASMonitor.shared.startMonitoring(interval: AppState.shared.checkInterval)
        
        AppState.shared.addLog(ActivityEntry(
            level: .info,
            category: .system,
            message: "The Annex started"
        ))
        
        mainWindowController.showWindow()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NASMonitor.shared.stopMonitoring()
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
                    NASMonitor.shared.setState(.syncing)
                } else if NASMonitor.shared.currentState == .syncing {
                    NASMonitor.shared.setState(.connected)
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
                jobItem.isEnabled = false
                menu.addItem(jobItem)
            }
            
            if SyncEngine.shared.isPaused {
                let resumeItem = NSMenuItem(title: "Resume Syncs", action: #selector(resumeSyncs), keyEquivalent: "")
                resumeItem.target = self
                menu.addItem(resumeItem)
            } else {
                let pauseItem = NSMenuItem(title: "Pause Syncs", action: #selector(pauseSyncs), keyEquivalent: "")
                pauseItem.target = self
                menu.addItem(pauseItem)
            }
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
    
    @objc private func pauseSyncs() {
        SyncEngine.shared.pauseAll()
    }
    
    @objc private func resumeSyncs() {
        SyncEngine.shared.resumeAll()
    }
    
    @objc private func openShare(_ sender: NSMenuItem) {
        guard let share = sender.representedObject as? String else { return }
        let path = "/Volumes/\(share)"
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
