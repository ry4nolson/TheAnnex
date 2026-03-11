import SwiftUI

struct AdvancedSettingsView: View {
    @State private var bandwidthLimit: String = "0"
    @State private var customRsyncFlags: String = ""
    @State private var enableWiFiFilter: Bool = false
    @State private var allowedSSIDs: String = ""
    @State private var onlyOnACPower: Bool = false
    @State private var showingSaveAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsGroup(title: "Bandwidth Control", icon: "speedometer") {
                    HStack {
                        Text("Bandwidth Limit:")
                        TextField("0", text: $bandwidthLimit)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("KB/s (0 = unlimited)")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .help("Limit rsync transfer speed in kilobytes per second")
                    .padding(12)
                }
                
                SettingsGroup(title: "Network Restrictions", icon: "wifi") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Only sync on specific WiFi networks", isOn: $enableWiFiFilter)
                            Spacer()
                        }
                        
                        if enableWiFiFilter {
                            HStack {
                                Text("Allowed SSIDs:")
                                TextField("Home, Office", text: $allowedSSIDs)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .help("Comma-separated list of WiFi network names")
                        }
                    }
                    .padding(12)
                }
                
                SettingsGroup(title: "Power Management", icon: "battery.100") {
                    HStack {
                        Toggle("Only sync when on AC power", isOn: $onlyOnACPower)
                            .help("Prevent syncing on battery to save power")
                        Spacer()
                    }
                    .padding(12)
                }
                
                SettingsGroup(title: "Personality", icon: "theatermasks") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Toggle("Show Annex personality", isOn: Binding(
                                get: { AnnexQuotes.shared.showPersonality },
                                set: { AnnexQuotes.shared.showPersonality = $0 }
                            ))
                            .help("Show fun quotes and easter eggs throughout the app")
                            Spacer()
                        }
                        
                        Text("When enabled, The Annex will show personality-driven quotes in notifications, logs, and empty states.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                }
                
                SettingsGroup(title: "Custom Rsync Options", icon: "terminal") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Additional rsync flags:")
                            .font(.subheadline)
                        TextEditor(text: $customRsyncFlags)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 80)
                            .border(Color.secondary.opacity(0.3))
                        Text("Advanced: Add custom rsync command-line flags (e.g., --delete, --compress)")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                
                HStack {
                    Spacer()
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .keyboardShortcut(.return)
                }
            }
            .padding()
        }
        .onAppear {
            loadSettings()
        }
        .alert("Settings Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your advanced settings have been saved successfully.")
        }
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
    
    private func loadSettings() {
        let limit = AppState.shared.bandwidthLimitKBps
        bandwidthLimit = limit > 0 ? "\(limit)" : "0"
    }
    
    private func saveSettings() {
        let limit = Int(bandwidthLimit) ?? 0
        AppState.shared.updateBandwidthLimit(limit)
        
        showingSaveAlert = true
    }
}
