import Cocoa
import UserNotifications

// MARK: - Shell Helper

@discardableResult
func shell(_ cmd: String) -> (output: String, exitCode: Int32) {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", cmd]
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    do {
        try task.run()
    } catch {
        return ("", 1)
    }
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return (output.trimmingCharacters(in: .whitespacesAndNewlines), task.terminationStatus)
}

// MARK: - UserDefaults Keys

private enum Defaults {
    static let nasHostname    = "nasHostname"
    static let nasUsername    = "nasUsername"
    static let nasShares      = "nasShares"
    static let downloadsPath  = "downloadsPath"
    static let checkInterval  = "checkInterval"

    // Default values
    static let defaultHostname     = "RyaNAS.local"
    static let defaultUsername     = "admin"
    static let defaultShares       = "home, Plex, Public"
    static let defaultDownloads    = "/Volumes/home/Downloads"
    static let defaultInterval: Int = 60
}

// MARK: - Activity Log Entry

struct LogEntry {
    let timestamp: Date
    let message: String

    var formattedTimestamp: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: timestamp)
    }
}

// MARK: - NAS State

enum NASState {
    case connected
    case offline
    case syncing
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSObject, NSWindowDelegate {

    var window: NSWindow?

    // Input controls
    private var hostnameField   = NSTextField()
    private var usernameField   = NSTextField()
    private var sharesField     = NSTextField()
    private var downloadsField  = NSTextField()
    private var intervalPopUp   = NSPopUpButton()

    // Interval options: (label, seconds)
    private let intervalOptions: [(String, Int)] = [
        ("30 seconds", 30),
        ("1 minute",   60),
        ("5 minutes",  300),
        ("10 minutes", 600),
    ]

    // Called after Save; AppDelegate restarts the timer.
    var onSave: (() -> Void)?

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        buildWindow()
        loadCurrentValues()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "NASManager Settings"
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()

        guard let contentView = w.contentView else { return }

        // --- Build labelled text fields ---
        func makeLabel(_ text: String) -> NSTextField {
            let lbl = NSTextField(labelWithString: text)
            lbl.alignment = .right
            lbl.translatesAutoresizingMaskIntoConstraints = false
            return lbl
        }

        func makeField() -> NSTextField {
            let f = NSTextField()
            f.translatesAutoresizingMaskIntoConstraints = false
            f.setContentHuggingPriority(.defaultLow, for: .horizontal)
            return f
        }

        let lblHostname   = makeLabel("NAS Hostname:")
        let lblUsername   = makeLabel("NAS Username:")
        let lblShares     = makeLabel("Shares (comma-separated):")
        let lblDownloads  = makeLabel("Downloads Path on NAS:")
        let lblInterval   = makeLabel("Check Interval:")

        hostnameField  = makeField()
        usernameField  = makeField()
        sharesField    = makeField()
        downloadsField = makeField()

        intervalPopUp = NSPopUpButton()
        intervalPopUp.translatesAutoresizingMaskIntoConstraints = false
        for (label, _) in intervalOptions {
            intervalPopUp.addItem(withTitle: label)
        }

        // --- Grid layout ---
        let grid = NSGridView(views: [
            [lblHostname,  hostnameField],
            [lblUsername,  usernameField],
            [lblShares,    sharesField],
            [lblDownloads, downloadsField],
            [lblInterval,  intervalPopUp],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.columnSpacing = 8
        grid.rowSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill

        // --- Buttons ---
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.keyEquivalent = "\r"
        saveBtn.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let btnStack = NSStackView(views: [cancelBtn, saveBtn])
        btnStack.orientation = .horizontal
        btnStack.spacing = 8
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(grid)
        contentView.addSubview(btnStack)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            btnStack.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 20),
            btnStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            btnStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
        ])

        self.window = w
    }

    private func loadCurrentValues() {
        let ud = UserDefaults.standard
        hostnameField.stringValue  = ud.string(forKey: Defaults.nasHostname)   ?? Defaults.defaultHostname
        usernameField.stringValue  = ud.string(forKey: Defaults.nasUsername)   ?? Defaults.defaultUsername
        sharesField.stringValue    = ud.string(forKey: Defaults.nasShares)     ?? Defaults.defaultShares
        downloadsField.stringValue = ud.string(forKey: Defaults.downloadsPath) ?? Defaults.defaultDownloads

        let savedInterval = ud.object(forKey: Defaults.checkInterval) != nil
            ? ud.integer(forKey: Defaults.checkInterval)
            : Defaults.defaultInterval

        // Select the matching popup item, default to index 0 if not found
        let matchIdx = intervalOptions.firstIndex(where: { $0.1 == savedInterval }) ?? 0
        intervalPopUp.selectItem(at: matchIdx)
    }

    @objc private func save() {
        let ud = UserDefaults.standard
        ud.set(hostnameField.stringValue,  forKey: Defaults.nasHostname)
        ud.set(usernameField.stringValue,  forKey: Defaults.nasUsername)
        ud.set(sharesField.stringValue,    forKey: Defaults.nasShares)
        ud.set(downloadsField.stringValue, forKey: Defaults.downloadsPath)

        let selectedIdx = intervalPopUp.indexOfSelectedItem
        let seconds = (selectedIdx >= 0 && selectedIdx < intervalOptions.count)
            ? intervalOptions[selectedIdx].1
            : Defaults.defaultInterval
        ud.set(seconds, forKey: Defaults.checkInterval)

        window?.orderOut(nil)
        onSave?()
    }

    @objc private func cancel() {
        window?.orderOut(nil)
    }

    // NSWindowDelegate — allow the window to be closed via the red button
    func windowWillClose(_ notification: Notification) {
        // nothing extra needed; isReleasedWhenClosed is false so we can reuse it
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Settings (computed from UserDefaults)

    var nasHostname: String {
        UserDefaults.standard.string(forKey: Defaults.nasHostname) ?? Defaults.defaultHostname
    }
    var nasUsername: String {
        UserDefaults.standard.string(forKey: Defaults.nasUsername) ?? Defaults.defaultUsername
    }
    var nasBase: String {
        "smb://\(nasUsername)@\(nasHostname)"
    }
    var shares: [String] {
        let raw = UserDefaults.standard.string(forKey: Defaults.nasShares) ?? Defaults.defaultShares
        return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    var nasDownloads: String {
        UserDefaults.standard.string(forKey: Defaults.downloadsPath) ?? Defaults.defaultDownloads
    }
    var checkInterval: TimeInterval {
        let stored = UserDefaults.standard.object(forKey: Defaults.checkInterval)
        let seconds = stored != nil ? UserDefaults.standard.integer(forKey: Defaults.checkInterval) : Defaults.defaultInterval
        return TimeInterval(seconds > 0 ? seconds : Defaults.defaultInterval)
    }
    var downloadsSymlink: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    // MARK: - State

    var currentState: NASState = .offline
    var activityLog: [LogEntry] = []
    var timer: Timer?

    // MARK: - UI

    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var settingsWindowController = SettingsWindowController()

    // MARK: - App Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        requestNotificationPermission()
        setupStatusItem()
        startTimer()

        settingsWindowController.onSave = { [weak self] in
            guard let self = self else { return }
            self.restartTimer()
            self.addLog("Settings saved — interval now \(Int(self.checkInterval))s")
            self.runCheckCycle()
        }

        runCheckCycle()
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendNotification(title: String, body: String) {
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

    // MARK: - Status Item Setup

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()
        statusItem.menu = menu
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbolName: String
        switch currentState {
        case .connected: symbolName = "externaldrive.fill.badge.checkmark"
        case .offline:   symbolName = "externaldrive.badge.xmark"
        case .syncing:   symbolName = "arrow.triangle.2.circlepath"
        }
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
        }
    }

    // MARK: - Menu Building

    func buildMenu() {
        menu = NSMenu()

        // Status line
        let stateItem = NSMenuItem()
        switch currentState {
        case .connected, .syncing:
            stateItem.title = "RyaNAS: Connected ✓"
        case .offline:
            stateItem.title = "RyaNAS: Offline ✗"
        }
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        // Downloads line
        let downloadsItem = NSMenuItem()
        downloadsItem.title = isDownloadsSymlink() ? "Downloads: NAS ☁️" : "Downloads: Local 💻"
        downloadsItem.isEnabled = false
        menu.addItem(downloadsItem)

        menu.addItem(NSMenuItem.separator())

        // Sync Now
        let syncItem = NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: "")
        syncItem.target = self
        menu.addItem(syncItem)

        // Recent Activity submenu
        let recentItem = NSMenuItem(title: "Recent Activity", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Recent Activity")
        let recentEntries = activityLog.suffix(5)
        if recentEntries.isEmpty {
            let emptyItem = NSMenuItem(title: "No activity yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for entry in recentEntries.reversed() {
                let entryItem = NSMenuItem(
                    title: "\(entry.formattedTimestamp)  \(entry.message)",
                    action: nil,
                    keyEquivalent: ""
                )
                entryItem.isEnabled = false
                submenu.addItem(entryItem)
            }
        }
        recentItem.submenu = submenu
        menu.addItem(recentItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Timer

    func startTimer() {
        let t = Timer.scheduledTimer(
            timeInterval: checkInterval,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func restartTimer() {
        timer?.invalidate()
        timer = nil
        startTimer()
    }

    @objc func timerFired() {
        runCheckCycle()
    }

    @objc func syncNow() {
        runCheckCycle()
    }

    @objc func openSettings() {
        settingsWindowController.showWindow()
    }

    // MARK: - Core Logic

    func runCheckCycle() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.performCheckCycle()
        }
    }

    func performCheckCycle() {
        let online = nasIsOnline()

        if online {
            mountShares()

            if !isDownloadsSymlink() {
                DispatchQueue.main.async { [weak self] in
                    self?.setStateSyncing()
                }

                syncDownloads()

                DispatchQueue.main.async { [weak self] in
                    self?.setStateConnected()
                    self?.sendNotification(
                        title: "NASManager",
                        body: "Downloads synced and re-linked to NAS"
                    )
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.setStateConnected()
                }
            }
        } else {
            if isDownloadsSymlink() {
                removeDownloadsSymlinkAndMkdir()
                DispatchQueue.main.async { [weak self] in
                    self?.sendNotification(
                        title: "NASManager",
                        body: "Downloads switched to local storage"
                    )
                }
            }

            DispatchQueue.main.async { [weak self] in
                self?.setStateOffline()
            }
        }
    }

    // MARK: - NAS Checks

    func nasIsOnline() -> Bool {
        let result = shell("ping -c 1 -t 2 \(nasHostname)")
        return result.exitCode == 0
    }

    func isDownloadsSymlink() -> Bool {
        let path = downloadsSymlink.path
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            let fileType = attrs[.type] as? FileAttributeType
            return fileType == .typeSymbolicLink
        } catch {
            return false
        }
    }

    // MARK: - Mount Shares

    func mountShares() {
        for share in shares {
            let mountPath = "/Volumes/\(share)"
            if !FileManager.default.fileExists(atPath: mountPath) {
                let url = "\(nasBase)/\(share)"
                let script = "tell application \"Finder\" to mount volume \"\(url)\""
                shell("osascript -e '\(script)'")
                addLog("Mounted share: \(share)")
            }
        }
    }

    // MARK: - Sync Downloads

    func syncDownloads() {
        let src = downloadsSymlink.path
        let dst = nasDownloads

        shell("mkdir -p \"\(dst)\"")

        let result = shell("rsync -a --ignore-existing \"\(src)/\" \"\(dst)/\"")
        if result.exitCode == 0 {
            addLog("Synced local Downloads to NAS")
        } else {
            addLog("Sync warning (exit \(result.exitCode)): \(result.output.prefix(80))")
        }

        do {
            try FileManager.default.removeItem(atPath: src)
        } catch {
            addLog("Failed to remove local Downloads: \(error.localizedDescription)")
            return
        }

        do {
            try FileManager.default.createSymbolicLink(atPath: src, withDestinationPath: dst)
            addLog("Symlink created: ~/Downloads -> \(dst)")
        } catch {
            addLog("Failed to create symlink: \(error.localizedDescription)")
        }
    }

    // MARK: - Remove Symlink

    func removeDownloadsSymlinkAndMkdir() {
        let path = downloadsSymlink.path
        do {
            try FileManager.default.removeItem(atPath: path)
            addLog("Removed Downloads symlink")
        } catch {
            addLog("Failed to remove symlink: \(error.localizedDescription)")
            return
        }
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            addLog("Created local ~/Downloads directory")
        } catch {
            addLog("Failed to create ~/Downloads: \(error.localizedDescription)")
        }
    }

    // MARK: - State Setters (must call on main thread)

    func setStateConnected() {
        let changed = currentState != .connected
        currentState = .connected
        updateIcon()
        buildMenu()
        if changed { addLog("State → Connected") }
    }

    func setStateOffline() {
        let changed = currentState != .offline
        currentState = .offline
        updateIcon()
        buildMenu()
        if changed { addLog("State → Offline") }
    }

    func setStateSyncing() {
        currentState = .syncing
        updateIcon()
        buildMenu()
        addLog("State → Syncing")
    }

    // MARK: - Activity Log

    func addLog(_ message: String) {
        let entry = LogEntry(timestamp: Date(), message: message)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activityLog.append(entry)
            if self.activityLog.count > 20 {
                self.activityLog.removeFirst(self.activityLog.count - 20)
            }
            self.buildMenu()
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
