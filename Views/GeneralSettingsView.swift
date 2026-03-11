import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var checkInterval: Int = 60
    @State private var launchAtLogin: Bool = false
    @State private var showingAddNAS = false
    @State private var selectedNAS: NASDevice?
    
    private let intervalOptions = [
        (label: "30 seconds", value: 30),
        (label: "1 minute", value: 60),
        (label: "5 minutes", value: 300),
        (label: "10 minutes", value: 600),
        (label: "30 minutes", value: 1800)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsGroup(title: "NAS Devices", icon: "externaldrive.connected.to.line.below") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Configured NAS Devices")
                                .font(.headline)
                            Spacer()
                            Button(action: { showingAddNAS = true }) {
                                Label("Add NAS", systemImage: "plus")
                            }
                        }
                        
                        if appState.nasDevices.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "externaldrive.badge.questionmark")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No NAS devices configured")
                                    .foregroundColor(.secondary)
                                Button("Add Your First NAS") {
                                    showingAddNAS = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ForEach(appState.nasDevices) { nas in
                                NASDeviceRow(
                                    device: nas,
                                    onEdit: {
                                        selectedNAS = nas
                                    },
                                    onSetDefault: {
                                        appState.setDefaultNAS(nas.id)
                                    },
                                    onDelete: {
                                        appState.removeNASDevice(nas)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
                
                SettingsGroup(title: "Monitoring", icon: "timer") {
                    HStack {
                        Text("Check Interval:")
                        Picker("", selection: $checkInterval) {
                            ForEach(intervalOptions, id: \.value) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                        Spacer()
                    }
                    .padding(12)
                }
                
                SettingsGroup(title: "Startup", icon: "power") {
                    HStack {
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                        Spacer()
                    }
                    .padding(12)
                }
                
                SettingsGroup(title: "Monitoring", icon: "chart.xyaxis.line") {
                    VStack(alignment: .leading, spacing: 8) {
                        if AppState.shared.nasDevices.isEmpty {
                            Text("No NAS devices configured")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(AppState.shared.nasDevices) { device in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: NASMonitor.shared.perDeviceOnline[device.id] == true ? "circle.fill" : "circle")
                                            .font(.caption2)
                                            .foregroundColor(NASMonitor.shared.perDeviceOnline[device.id] == true ? .green : .red)
                                        Text(device.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(device.hostname)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(NASMonitor.shared.perDeviceOnline[device.id] == true ? "Online" : "Offline")
                                            .font(.caption)
                                            .foregroundColor(NASMonitor.shared.perDeviceOnline[device.id] == true ? .green : .red)
                                    }
                                    
                                    if NASMonitor.shared.perDeviceOnline[device.id] == true {
                                        HStack(spacing: 16) {
                                            if let quality = NASMonitor.shared.perDeviceQuality[device.id] {
                                                HStack(spacing: 4) {
                                                    Text(quality.qualityLevel.rawValue)
                                                        .foregroundColor(qualityColor(quality.qualityLevel))
                                                    if let latency = quality.latency {
                                                        Text("• \(String(format: "%.1f", latency))ms")
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Text("• \(String(format: "%.1f", quality.packetLoss))% loss")
                                                        .foregroundColor(.secondary)
                                                }
                                                .font(.caption)
                                            }
                                            
                                            Spacer()
                                            
                                            if let diskSpace = NASMonitor.shared.perDeviceDiskSpace[device.id] {
                                                HStack(spacing: 4) {
                                                    Text("\(diskSpace.freeFormatted) free of \(diskSpace.totalFormatted)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    ProgressView(value: diskSpace.usedPercentage, total: 100)
                                                        .frame(width: 100)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(6)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(12)
                }
            }
            .padding()
        }
        
        Divider()
        HStack {
            Spacer()
            Button("Save Settings") {
                saveSettings()
            }
            .keyboardShortcut(.return)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear {
            loadSettings()
            NASMonitor.shared.performHealthCheck()
        }
        .sheet(isPresented: $showingAddNAS) {
            AddNASSheet(isPresented: $showingAddNAS)
        }
        .sheet(item: $selectedNAS) { nas in
            EditNASSheet(device: nas, isPresented: Binding(
                get: { selectedNAS != nil },
                set: { if !$0 { selectedNAS = nil } }
            ))
        }
    }
    
    private func loadSettings() {
        checkInterval = Int(appState.checkInterval)
        launchAtLogin = appState.launchAtLogin
    }
    
    private func saveSettings() {
        appState.updateCheckInterval(checkInterval)
        appState.launchAtLogin = launchAtLogin
        NASMonitor.shared.startMonitoring(interval: TimeInterval(checkInterval))
    }
    
    private func qualityColor(_ level: ConnectionQuality.QualityLevel) -> Color {
        switch level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
}

struct NASDeviceRow: View {
    let device: NASDevice
    let onEdit: () -> Void
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.isDefault ? "star.fill" : "star")
                .foregroundColor(device.isDefault ? .yellow : .secondary)
                .onTapGesture {
                    onSetDefault()
                }
                .help(device.isDefault ? "Default NAS" : "Set as default")
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                Text(device.hostname)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !device.shares.isEmpty {
                    Text("Shares: \(device.shares.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .help("Edit")
            
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .help("Delete")
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct AddNASSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var discovery = NASDiscovery()
    @State private var name = ""
    @State private var hostname = ""
    @State private var username = "admin"
    @State private var password = ""
    @State private var shares: [String] = []
    @State private var detectedShares: [String] = []
    @State private var isScanning = false
    @State private var selectedDiscovered: DiscoveredNAS?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add NAS Device")
                .font(.title2)
                .fontWeight(.bold)
            
            GroupBox(label: Label("Discover NAS", systemImage: "magnifyingglass")) {
                VStack(spacing: 12) {
                    HStack {
                        Button(action: scanNetwork) {
                            Label(isScanning ? "Scanning..." : "Scan Network", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .disabled(isScanning)
                        
                        Spacer()
                        
                        if !discovery.discoveredDevices.isEmpty {
                            Text("\(discovery.discoveredDevices.count) found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !discovery.discoveredDevices.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(discovery.discoveredDevices) { device in
                                Button(action: {
                                    selectedDiscovered = device
                                    hostname = device.hostname
                                    name = device.name
                                    detectShares()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(device.name)
                                                .font(.headline)
                                            Text(device.hostname)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedDiscovered?.id == device.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(selectedDiscovered?.id == device.id ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                
                                if device.id != discovery.discoveredDevices.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            GroupBox(label: Label("NAS Details", systemImage: "externaldrive")) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Name (e.g., RyaNAS)", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Hostname (e.g., RyaNAS.local)", text: $hostname)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Shares")
                                .font(.subheadline)
                            Spacer()
                            Button(action: detectShares) {
                                Label("Detect", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                            }
                            .disabled(hostname.isEmpty)
                            .help("Detect mounted shares from this NAS")
                            Button(action: browseForShare) {
                                Label("Browse", systemImage: "folder")
                                    .font(.caption)
                            }
                            .help("Browse /Volumes for a share")
                        }
                        
                        if !detectedShares.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(detectedShares, id: \.self) { share in
                                    Button(action: { toggleShare(share) }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: shares.contains(share) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(shares.contains(share) ? .blue : .secondary)
                                                .font(.caption)
                                            Text(share)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(shares.contains(share) ? Color.blue.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if !shares.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(shares, id: \.self) { share in
                                    HStack(spacing: 2) {
                                        Text(share)
                                            .font(.caption)
                                        Button(action: { shares.removeAll { $0 == share } }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                        } else {
                            Text("No shares selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    addNAS()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || hostname.isEmpty || username.isEmpty)
            }
        }
        .frame(width: 500)
        .padding(20)
    }
    
    private func scanNetwork() {
        isScanning = true
        discovery.scanLocalNetwork()
        
        // Poll until devices are found or timeout after 10 seconds
        var elapsed = 0.0
        let interval = 0.5
        func checkResults() {
            elapsed += interval
            if !discovery.discoveredDevices.isEmpty || elapsed >= 10.0 {
                isScanning = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    checkResults()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            checkResults()
        }
    }
    
    private func detectShares() {
        let volumesPath = "/Volumes"
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: volumesPath) {
            // Show all non-system volumes as potential shares
            let found = contents.filter { item in
                item != "Macintosh HD" && item != "Recovery" && !item.hasPrefix(".")
            }
            detectedShares = found
        }
    }
    
    private func toggleShare(_ share: String) {
        if shares.contains(share) {
            shares.removeAll { $0 == share }
        } else {
            shares.append(share)
        }
    }
    
    private func browseForShare() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        panel.prompt = "Select Share"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                let shareName = url.lastPathComponent
                if !shares.contains(shareName) {
                    shares.append(shareName)
                }
            }
        }
    }
    
    private func addNAS() {
        let sharesList = shares
        let isFirstNAS = AppState.shared.nasDevices.isEmpty
        let device = NASDevice(
            name: name,
            hostname: hostname,
            username: username,
            shares: sharesList
        )
        
        AppState.shared.addNASDevice(device)
        
        if !password.isEmpty {
            _ = KeychainHelper.shared.save(password: password, for: "nas_\(device.id.uuidString)")
        }
        
        if isFirstNAS, let quote = AnnexQuotes.shared.quote(AnnexQuotes.firstNASAdded) {
            AppState.shared.addLog(ActivityEntry(
                level: .info,
                category: .system,
                message: "First NAS added: \(name) — \"\(quote)\""
            ))
        }
        
        isPresented = false
    }
}

struct EditNASSheet: View {
    let device: NASDevice
    @Binding var isPresented: Bool
    
    @State private var name: String
    @State private var hostname: String
    @State private var username: String
    @State private var password: String = ""
    @State private var shares: [String]
    
    init(device: NASDevice, isPresented: Binding<Bool>) {
        self.device = device
        self._isPresented = isPresented
        self._name = State(initialValue: device.name)
        self._hostname = State(initialValue: device.hostname)
        self._username = State(initialValue: device.username)
        self._shares = State(initialValue: device.shares)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit: \(device.name)")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Hostname", text: $hostname)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Password (leave blank to keep current)", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Text("Shares:")
                        .font(.subheadline)
                    Spacer()
                    Button(action: browseForShare) {
                        Label("Browse", systemImage: "folder")
                            .font(.caption)
                    }
                }
                
                if !shares.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(shares, id: \.self) { share in
                            HStack(spacing: 2) {
                                Text(share)
                                    .font(.caption)
                                Button(action: { shares.removeAll { $0 == share } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                } else {
                    Text("No shares selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 450)
        .padding(20)
    }
    
    private func browseForShare() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        panel.prompt = "Select Share"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                let shareName = url.lastPathComponent
                if !shares.contains(shareName) {
                    shares.append(shareName)
                }
            }
        }
    }
    
    private func saveChanges() {
        var updated = device
        updated.name = name
        updated.hostname = hostname
        updated.username = username
        updated.shares = shares
        
        AppState.shared.updateNASDevice(updated)
        
        if !password.isEmpty {
            _ = KeychainHelper.shared.save(password: password, for: "nas_\(device.id.uuidString)")
        }
        
        isPresented = false
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                )
        }
    }
}
