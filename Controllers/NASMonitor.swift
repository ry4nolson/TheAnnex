import Foundation
import Combine

class NASMonitor: ObservableObject {
    static let shared = NASMonitor()
    
    @Published var currentState: NASState = .offline
    @Published var connectionQuality: ConnectionQuality?
    @Published var localDiskSpace: DiskSpace?
    @Published var nasDiskSpace: DiskSpace?
    @Published var perDeviceQuality: [UUID: ConnectionQuality] = [:]
    @Published var perDeviceDiskSpace: [UUID: DiskSpace] = [:]
    @Published var perDeviceOnline: [UUID: Bool] = [:]
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    var onLog: ((ActivityEntry) -> Void)?
    var onStateChange: ((NASState) -> Void)?
    private(set) var hasCompletedInitialCheck = false
    
    private init() {}
    
    func startMonitoring(interval: TimeInterval) {
        stopMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        performHealthCheck()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func performHealthCheck() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let devices = AppState.shared.nasDevices
            guard !devices.isEmpty else {
                DispatchQueue.main.async {
                    self.currentState = .offline
                }
                return
            }
            
            var anyOnline = false
            var onlineStatus: [UUID: Bool] = [:]
            
            for device in devices {
                let isOnline = NetworkDetector.pingHost(device.hostname)
                onlineStatus[device.id] = isOnline
                if isOnline {
                    anyOnline = true
                }
            }
            
            DispatchQueue.main.async {
                let previousState = self.currentState
                self.perDeviceOnline = onlineStatus
                
                self.hasCompletedInitialCheck = true
                
                if anyOnline {
                    if previousState == .offline {
                        self.currentState = .connected
                        self.log(.info, category: .network, message: "NAS devices are online")
                        self.onStateChange?(.connected)
                        self.mountAllShares()
                    } else if previousState != .syncing {
                        self.currentState = .connected
                    }
                    
                    // Get quality and disk space per device
                    for device in devices {
                        if onlineStatus[device.id] == true {
                            let deviceId = device.id
                            let hostname = device.hostname
                            let shares = device.shares
                            DispatchQueue.global(qos: .utility).async {
                                let quality = NetworkDetector.getConnectionQuality(to: hostname)
                                var diskSpace: DiskSpace?
                                if !shares.isEmpty {
                                    let nasPath = "/Volumes/\(shares[0])"
                                    if FileManager.default.fileExists(atPath: nasPath) {
                                        diskSpace = self.getDiskSpace(for: nasPath)
                                    }
                                }
                                DispatchQueue.main.async {
                                    self.perDeviceQuality[deviceId] = quality
                                    if let ds = diskSpace {
                                        self.perDeviceDiskSpace[deviceId] = ds
                                    }
                                    // Also update legacy single-device fields for backward compat
                                    if deviceId == AppState.shared.defaultNAS?.id {
                                        self.connectionQuality = quality
                                        if let ds = diskSpace {
                                            self.nasDiskSpace = ds
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    self.updateDiskSpace()
                } else {
                    if previousState != .offline {
                        self.currentState = .offline
                        self.log(.warning, category: .network, message: "All NAS devices are offline")
                        self.onStateChange?(.offline)
                    }
                    self.perDeviceQuality = [:]
                    self.perDeviceDiskSpace = [:]
                    self.connectionQuality = nil
                    self.nasDiskSpace = nil
                }
            }
        }
    }
    
    func mountAllShares() {
        let devices = AppState.shared.nasDevices
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for device in devices {
                self?.mountSharesSync(for: device)
            }
        }
    }
    
    func mountShares(for device: NASDevice) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.mountSharesSync(for: device)
        }
    }
    
    private func mountSharesSync(for device: NASDevice) {
        for share in device.shares {
            let mountPath = "/Volumes/\(share)"
            if !FileManager.default.fileExists(atPath: mountPath) {
                let url = device.authenticatedShareURL(for: share)
                let script = "tell application \"Finder\" to mount volume \"\(url)\""
                let result = ShellHelper.runDirect("/usr/bin/osascript", arguments: ["-e", script])
                
                if result.isSuccess {
                    log(.info, category: .mount, message: "Mounted \(device.name)/\(share)")
                } else {
                    log(.error, category: .mount, message: "Failed to mount \(device.name)/\(share): \(result.error ?? result.output)")
                }
            }
        }
    }
    
    func unmountShare(_ share: String) {
        let mountPath = "/Volumes/\(share)"
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = ShellHelper.runDirect("/usr/sbin/diskutil", arguments: ["unmount", mountPath])
            
            if result.isSuccess {
                self?.log(.info, category: .mount, message: "Unmounted share: \(share)")
            } else {
                self?.log(.error, category: .mount, message: "Failed to unmount share: \(share)")
            }
        }
    }
    
    private func updateDiskSpace() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let homePath = NSHomeDirectory()
            if let homeSpace = self?.getDiskSpace(for: homePath) {
                DispatchQueue.main.async {
                    self?.localDiskSpace = homeSpace
                }
            }
            
            if let defaultNAS = AppState.shared.defaultNAS,
               !defaultNAS.shares.isEmpty {
                let nasPath = "/Volumes/\(defaultNAS.shares[0])"
                if FileManager.default.fileExists(atPath: nasPath),
                   let nasSpace = self?.getDiskSpace(for: nasPath) {
                    DispatchQueue.main.async {
                        self?.nasDiskSpace = nasSpace
                    }
                }
            }
        }
    }
    
    private func getDiskSpace(for path: String) -> DiskSpace? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            
            guard let totalSize = attributes[.systemSize] as? Int64,
                  let freeSize = attributes[.systemFreeSize] as? Int64 else {
                return nil
            }
            
            let usedSize = totalSize - freeSize
            
            return DiskSpace(
                totalBytes: totalSize,
                usedBytes: usedSize,
                freeBytes: freeSize
            )
        } catch {
            return nil
        }
    }
    
    func setState(_ state: NASState) {
        if currentState != state {
            currentState = state
            onStateChange?(state)
        }
    }
    
    private func log(_ level: LogLevel, category: LogCategory, message: String, details: String? = nil) {
        let entry = ActivityEntry(level: level, category: category, message: message, details: details)
        onLog?(entry)
    }
}

struct DiskSpace {
    let totalBytes: Int64
    let usedBytes: Int64
    let freeBytes: Int64
    
    var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    var usedFormatted: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    var freeFormatted: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }
    
    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}
