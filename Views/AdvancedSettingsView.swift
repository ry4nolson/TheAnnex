import SwiftUI

struct AdvancedSettingsView: View {
    @State private var bandwidthLimit: String = "0"
    @State private var customRsyncFlags: String = ""
    @State private var enableWiFiFilter: Bool = false
    @State private var allowedSSIDs: String = ""
    @State private var onlyOnACPower: Bool = false
    @State private var showingSaveAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
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
        }
        .alert("Settings Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your advanced settings have been saved successfully.")
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
