import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var nasDevices: [NASDevice] = []
    @Published var syncFolders: [SyncFolder] = []
    @Published var activityLog: [ActivityEntry] = []
    @Published var statistics = Statistics()
    
    private let defaults = UserDefaults.standard
    private let maxLogEntries = 1000
    
    private enum Keys {
        static let nasDevices = "nasDevices"
        static let checkInterval = "checkInterval"
        static let syncFolders = "syncFolders"
        static let statistics = "statistics"
        static let bandwidthLimit = "bandwidthLimit"
        static let launchAtLogin = "launchAtLogin"
        static let activityLog = "activityLog"
        
        static let defaultInterval = 60
    }
    
    var defaultNAS: NASDevice? {
        nasDevices.first { $0.isDefault } ?? nasDevices.first
    }
    
    func getNASDevice(id: UUID) -> NASDevice? {
        nasDevices.first { $0.id == id }
    }
    
    var checkInterval: TimeInterval {
        let stored = defaults.object(forKey: Keys.checkInterval)
        let seconds = stored != nil ? defaults.integer(forKey: Keys.checkInterval) : Keys.defaultInterval
        return TimeInterval(seconds > 0 ? seconds : Keys.defaultInterval)
    }
    
    var bandwidthLimitKBps: Int {
        defaults.integer(forKey: Keys.bandwidthLimit)
    }
    
    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }
    
    private init() {
        loadNASDevices()
        loadSyncFolders()
        loadStatistics()
        loadActivityLog()
    }
    
    func updateCheckInterval(_ interval: Int) {
        defaults.set(interval, forKey: Keys.checkInterval)
    }
    
    func loadNASDevices() {
        if let data = defaults.data(forKey: Keys.nasDevices),
           let devices = try? JSONDecoder().decode([NASDevice].self, from: data) {
            nasDevices = devices
        } else {
            nasDevices = []
        }
    }
    
    func saveNASDevices() {
        if let data = try? JSONEncoder().encode(nasDevices) {
            defaults.set(data, forKey: Keys.nasDevices)
        }
    }
    
    func addNASDevice(_ device: NASDevice) {
        var newDevice = device
        if nasDevices.isEmpty {
            newDevice.isDefault = true
        }
        nasDevices.append(newDevice)
        saveNASDevices()
    }
    
    func updateNASDevice(_ device: NASDevice) {
        if let index = nasDevices.firstIndex(where: { $0.id == device.id }) {
            nasDevices[index] = device
            saveNASDevices()
        }
    }
    
    func removeNASDevice(_ device: NASDevice) {
        nasDevices.removeAll { $0.id == device.id }
        if !nasDevices.isEmpty && device.isDefault {
            nasDevices[0].isDefault = true
        }
        saveNASDevices()
    }
    
    func setDefaultNAS(_ deviceId: UUID) {
        for i in 0..<nasDevices.count {
            nasDevices[i].isDefault = (nasDevices[i].id == deviceId)
        }
        saveNASDevices()
    }
    
    func updateBandwidthLimit(_ limitKBps: Int) {
        defaults.set(limitKBps, forKey: Keys.bandwidthLimit)
    }
    
    func loadSyncFolders() {
        if let data = defaults.data(forKey: Keys.syncFolders),
           let folders = try? JSONDecoder().decode([SyncFolder].self, from: data) {
            syncFolders = folders
        } else {
            syncFolders = []
        }
    }
    
    func saveSyncFolders() {
        if let data = try? JSONEncoder().encode(syncFolders) {
            defaults.set(data, forKey: Keys.syncFolders)
        }
    }
    
    func addSyncFolder(_ folder: SyncFolder) {
        syncFolders.append(folder)
        saveSyncFolders()
    }
    
    func updateSyncFolder(_ folder: SyncFolder) {
        if let index = syncFolders.firstIndex(where: { $0.id == folder.id }) {
            syncFolders[index] = folder
            saveSyncFolders()
        }
    }
    
    func removeSyncFolder(_ folder: SyncFolder) {
        syncFolders.removeAll { $0.id == folder.id }
        saveSyncFolders()
    }
    
    func addLog(_ entry: ActivityEntry) {
        activityLog.insert(entry, at: 0)
        if activityLog.count > maxLogEntries {
            activityLog.removeLast()
        }
        saveActivityLog()
    }
    
    func loadActivityLog() {
        if let data = defaults.data(forKey: Keys.activityLog),
           let logs = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            activityLog = logs
        }
    }
    
    func saveActivityLog() {
        if let data = try? JSONEncoder().encode(activityLog) {
            defaults.set(data, forKey: Keys.activityLog)
        }
    }
    
    func clearLogs() {
        activityLog.removeAll()
    }
    
    func exportLogs() -> String {
        var output = "The Annex Activity Log\n"
        output += "Generated: \(Date())\n"
        output += String(repeating: "=", count: 80) + "\n\n"
        
        for entry in activityLog {
            output += "[\(entry.formattedDate)] [\(entry.level.displayName)] [\(entry.category.displayName)]\n"
            output += entry.message + "\n"
            if let details = entry.details {
                output += "Details: \(details)\n"
            }
            output += "\n"
        }
        
        return output
    }
    
    func loadStatistics() {
        if let data = defaults.data(forKey: Keys.statistics),
           let stats = try? JSONDecoder().decode(Statistics.self, from: data) {
            statistics = stats
        }
    }
    
    func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            defaults.set(data, forKey: Keys.statistics)
        }
    }
}
