import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var nasDevices: [NASDevice] = []
    @Published var syncFolders: [SyncFolder] = []
    var activityLog: [ActivityEntry] = []
    private var pendingLogEntries: [ActivityEntry] = []
    private let logLock = NSLock()
    private var logFlushScheduled = false
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
        static let wifiFilterEnabled = "wifiFilterEnabled"
        static let allowedSSIDs = "allowedSSIDs"
        static let acPowerOnly = "acPowerOnly"
        static let customRsyncFlags = "customRsyncFlags"
        
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
    
    var wifiFilterEnabled: Bool {
        get { defaults.bool(forKey: Keys.wifiFilterEnabled) }
        set { defaults.set(newValue, forKey: Keys.wifiFilterEnabled) }
    }
    
    var allowedSSIDs: [String] {
        get {
            let raw = defaults.string(forKey: Keys.allowedSSIDs) ?? ""
            return raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            defaults.set(newValue.joined(separator: ", "), forKey: Keys.allowedSSIDs)
        }
    }
    
    var allowedSSIDsRaw: String {
        get { defaults.string(forKey: Keys.allowedSSIDs) ?? "" }
        set { defaults.set(newValue, forKey: Keys.allowedSSIDs) }
    }
    
    var acPowerOnly: Bool {
        get { defaults.bool(forKey: Keys.acPowerOnly) }
        set { defaults.set(newValue, forKey: Keys.acPowerOnly) }
    }
    
    var customRsyncFlags: String {
        get { defaults.string(forKey: Keys.customRsyncFlags) ?? "" }
        set { defaults.set(newValue, forKey: Keys.customRsyncFlags) }
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
        guard let data = defaults.data(forKey: Keys.nasDevices) else {
            nasDevices = []
            return
        }
        do {
            nasDevices = try JSONDecoder().decode([NASDevice].self, from: data)
        } catch {
            NSLog("[AppState] Failed to decode NAS devices: %@", error.localizedDescription)
            nasDevices = []
        }
    }
    
    func saveNASDevices() {
        do {
            let data = try JSONEncoder().encode(nasDevices)
            defaults.set(data, forKey: Keys.nasDevices)
        } catch {
            NSLog("[AppState] Failed to encode NAS devices: %@", error.localizedDescription)
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
        guard let data = defaults.data(forKey: Keys.syncFolders) else {
            syncFolders = []
            return
        }
        do {
            syncFolders = try JSONDecoder().decode([SyncFolder].self, from: data)
        } catch {
            NSLog("[AppState] Failed to decode sync folders: %@", error.localizedDescription)
            syncFolders = []
        }
    }
    
    func saveSyncFolders() {
        do {
            let data = try JSONEncoder().encode(syncFolders)
            defaults.set(data, forKey: Keys.syncFolders)
        } catch {
            NSLog("[AppState] Failed to encode sync folders: %@", error.localizedDescription)
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
        logLock.lock()
        pendingLogEntries.append(entry)
        let needsSchedule = !logFlushScheduled
        logFlushScheduled = true
        logLock.unlock()
        
        if needsSchedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.flushLogs()
            }
        }
    }
    
    private func flushLogs() {
        logLock.lock()
        let entries = pendingLogEntries
        pendingLogEntries.removeAll(keepingCapacity: true)
        logFlushScheduled = false
        logLock.unlock()
        
        guard !entries.isEmpty else { return }
        
        for entry in entries {
            activityLog.insert(entry, at: 0)
        }
        if activityLog.count > maxLogEntries {
            activityLog.removeLast(activityLog.count - maxLogEntries)
        }
        objectWillChange.send()
        saveActivityLog()
    }
    
    func loadActivityLog() {
        guard let data = defaults.data(forKey: Keys.activityLog) else { return }
        do {
            activityLog = try JSONDecoder().decode([ActivityEntry].self, from: data)
        } catch {
            NSLog("[AppState] Failed to decode activity log: %@", error.localizedDescription)
        }
    }
    
    func saveActivityLog() {
        do {
            let data = try JSONEncoder().encode(activityLog)
            defaults.set(data, forKey: Keys.activityLog)
        } catch {
            NSLog("[AppState] Failed to encode activity log: %@", error.localizedDescription)
        }
    }
    
    func clearLogs() {
        activityLog.removeAll()
        objectWillChange.send()
        saveActivityLog()
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
        guard let data = defaults.data(forKey: Keys.statistics) else { return }
        do {
            statistics = try JSONDecoder().decode(Statistics.self, from: data)
        } catch {
            NSLog("[AppState] Failed to decode statistics: %@", error.localizedDescription)
        }
    }
    
    func saveStatistics() {
        do {
            let data = try JSONEncoder().encode(statistics)
            defaults.set(data, forKey: Keys.statistics)
        } catch {
            NSLog("[AppState] Failed to encode statistics: %@", error.localizedDescription)
        }
    }
}
