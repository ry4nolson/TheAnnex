import Cocoa
import SwiftUI

class MainWindowController: NSObject, NSWindowDelegate {
    var window: NSWindow?
    
    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        buildWindow()
        loadAppIcon()
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func buildWindow() {
        let contentView = MainWindowView()
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "The Annex"
        w.contentViewController = hostingController
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        w.setFrameAutosaveName("MainWindow")
        
        self.window = w
    }
    
    private func loadAppIcon() {
        if let resourcePath = Bundle.main.resourcePath {
            let iconPath = (resourcePath as NSString).appendingPathComponent("AppIcon.png")
            if let image = NSImage(contentsOfFile: iconPath) {
                let size = NSSize(width: 256, height: 256)
                let rounded = NSImage(size: size)
                rounded.lockFocus()
                let rect = NSRect(origin: .zero, size: size)
                let path = NSBezierPath(roundedRect: rect, xRadius: size.width * 0.22, yRadius: size.height * 0.22)
                path.addClip()
                image.draw(in: rect)
                rounded.unlockFocus()
                NSApp.applicationIconImage = rounded
            }
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct SettingsSection: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    
    static let general = SettingsSection(id: "general", title: "General", icon: "gear")
    static let syncFolders = SettingsSection(id: "syncFolders", title: "Sync Folders", icon: "folder.badge.gearshape")
    static let activityLog = SettingsSection(id: "activityLog", title: "Activity Log", icon: "list.bullet.rectangle")
    static let statistics = SettingsSection(id: "statistics", title: "Statistics", icon: "chart.bar")
    static let advanced = SettingsSection(id: "advanced", title: "Advanced", icon: "slider.horizontal.3")
    static let about = SettingsSection(id: "about", title: "About", icon: "info.circle")
    static let whatsNew = SettingsSection(id: "whatsNew", title: "What's New", icon: "sparkles")
    
    static let allSections = [general, syncFolders, activityLog, statistics, advanced, whatsNew, about]
}

struct MainWindowView: View {
    @State private var selectedSection: SettingsSection? = .general
    @State private var showWelcomeSheet: Bool = false
    
    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allSections, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            .listStyle(.sidebar)
        } detail: {
            if let section = selectedSection {
                detailView(for: section)
            } else {
                Text("Select a section")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
                showWelcomeSheet = true
            }
        }
        .sheet(isPresented: $showWelcomeSheet) {
            WelcomeSheet(isPresented: $showWelcomeSheet)
        }
    }
    
    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section.id {
        case "general":
            GeneralSettingsView()
        case "syncFolders":
            SyncFoldersView()
        case "activityLog":
            ActivityLogView()
        case "statistics":
            StatisticsView()
        case "advanced":
            AdvancedSettingsView()
        case "whatsNew":
            ChangelogView()
        case "about":
            AboutView()
        default:
            Text("Unknown section")
        }
    }
}

struct WelcomeSheet: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            AppIconView(size: 96)
            
            Text("Welcome to The Annex")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("The Annex quietly syncs your Mac's folders to your NAS — so everything feels local, even when it's not.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)
            
            Text(AnnexQuotes.firstLaunchWelcome)
                .font(.caption)
                .italic()
                .foregroundColor(.secondary.opacity(0.7))
                .frame(maxWidth: 400)
            
            Spacer()
            
            Button(action: {
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                isPresented = false
            }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(minWidth: 200)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .padding(.bottom, 30)
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}
