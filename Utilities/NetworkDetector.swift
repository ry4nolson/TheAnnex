import Foundation
import CoreWLAN
import IOKit.ps

class NetworkDetector {
    static func getCurrentWiFiSSID() -> String? {
        let client = CWWiFiClient.shared()
        guard let interface = client.interface(),
              let ssid = interface.ssid() else {
            return nil
        }
        return ssid
    }
    
    static func isOnACPower() -> Bool {
        guard let snapshotRef = IOPSCopyPowerSourcesInfo() else { return true }
        let snapshot = snapshotRef.takeRetainedValue()
        guard let sourcesRef = IOPSCopyPowerSourcesList(snapshot) else { return true }
        let sources = sourcesRef.takeRetainedValue() as Array
        
        for source in sources {
            guard let descRef = IOPSGetPowerSourceDescription(snapshot, source) else { continue }
            if let description = descRef.takeUnretainedValue() as? [String: Any] {
                if let powerSource = description[kIOPSPowerSourceStateKey] as? String {
                    return powerSource == kIOPSACPowerValue
                }
            }
        }
        
        return true
    }
    
    static func getBatteryLevel() -> Int? {
        guard let snapshotRef = IOPSCopyPowerSourcesInfo() else { return nil }
        let snapshot = snapshotRef.takeRetainedValue()
        guard let sourcesRef = IOPSCopyPowerSourcesList(snapshot) else { return nil }
        let sources = sourcesRef.takeRetainedValue() as Array
        
        for source in sources {
            guard let descRef = IOPSGetPowerSourceDescription(snapshot, source) else { continue }
            if let description = descRef.takeUnretainedValue() as? [String: Any] {
                if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int {
                    return currentCapacity
                }
            }
        }
        
        return nil
    }
    
    static func isConnectedToWiFi(ssids: [String]) -> Bool {
        guard let currentSSID = getCurrentWiFiSSID() else {
            return false
        }
        
        if ssids.isEmpty {
            return true
        }
        
        return ssids.contains(currentSSID)
    }
    
    static func pingHost(_ hostname: String, timeout: Int = 2) -> Bool {
        let result = ShellHelper.runDirect("/sbin/ping", arguments: ["-c", "1", "-t", "\(timeout)", hostname], timeout: TimeInterval(timeout + 1))
        return result.isSuccess
    }
    
    static func getConnectionQuality(to hostname: String) -> ConnectionQuality {
        let result = ShellHelper.runDirect("/sbin/ping", arguments: ["-c", "10", hostname])
        
        guard result.isSuccess else {
            return ConnectionQuality(latency: nil, packetLoss: 100.0)
        }
        
        var latency: Double?
        var packetLoss: Double = 0.0
        
        let lines = result.output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("packet loss") {
                let components = line.components(separatedBy: ",")
                for component in components {
                    if component.contains("%") && component.contains("packet loss") {
                        let percentString = component.trimmingCharacters(in: .whitespaces).components(separatedBy: "%")[0]
                        packetLoss = Double(percentString) ?? 0.0
                    }
                }
            } else if line.contains("avg") {
                let components = line.components(separatedBy: "=")
                if components.count > 1 {
                    let stats = components[1].trimmingCharacters(in: .whitespaces).components(separatedBy: "/")
                    if stats.count > 1 {
                        latency = Double(stats[1])
                    }
                }
            }
        }
        
        return ConnectionQuality(latency: latency, packetLoss: packetLoss)
    }
}

struct ConnectionQuality {
    let latency: Double?
    let packetLoss: Double
    
    var qualityLevel: QualityLevel {
        if packetLoss > 10 {
            return .poor
        }
        
        guard let latency = latency else {
            return .unknown
        }
        
        if latency < 20 {
            return .excellent
        } else if latency < 50 {
            return .good
        } else if latency < 100 {
            return .fair
        } else {
            return .poor
        }
    }
    
    enum QualityLevel: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case unknown = "Unknown"
    }
}
