import Foundation
import Network

class NASDiscovery: NSObject, ObservableObject {
    @Published var discoveredDevices: [DiscoveredNAS] = []
    
    private var browser: NWBrowser?
    private var isScanning = false
    private var bonjourResults: [DiscoveredNAS] = []
    
    func startDiscovery() {
        guard !isScanning else { return }
        isScanning = true
        discoveredDevices.removeAll()
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let browser = NWBrowser(for: .bonjour(type: "_smb._tcp", domain: nil), using: parameters)
        
        browser.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                print("NAS Discovery: Browser ready")
            case .failed(let error):
                print("NAS Discovery: Browser failed - \(error)")
                self?.isScanning = false
            case .cancelled:
                self?.isScanning = false
            default:
                break
            }
        }
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                self?.handleBrowseResults(results)
            }
        }
        
        browser.start(queue: .main)
        self.browser = browser
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.stopDiscovery()
        }
    }
    
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isScanning = false
    }
    
    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var devices: [DiscoveredNAS] = []
        
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                let hostname = "\(name).local"
                let device = DiscoveredNAS(
                    hostname: hostname,
                    name: name,
                    serviceType: type
                )
                devices.append(device)
            default:
                break
            }
        }
        
        discoveredDevices = devices.sorted { $0.name < $1.name }
    }
    
    func scanLocalNetwork() {
        discoveredDevices.removeAll()
        bonjourResults.removeAll()
        
        // Phase 1: Bonjour/mDNS discovery for SMB services (finds any NAS advertising SMB)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let smbBrowser = NWBrowser(for: .bonjour(type: "_smb._tcp", domain: nil), using: parameters)
        
        smbBrowser.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("NAS Discovery: Bonjour scan ready")
            case .failed(let error):
                print("NAS Discovery: Bonjour scan failed - \(error)")
            default:
                break
            }
        }
        
        smbBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            var devices: [DiscoveredNAS] = []
            for result in results {
                switch result.endpoint {
                case .service(let name, _, _, _):
                    let hostname = "\(name).local"
                    // Filter out Macs and common non-NAS devices
                    let device = DiscoveredNAS(
                        hostname: hostname,
                        name: name,
                        serviceType: "_smb._tcp"
                    )
                    devices.append(device)
                default:
                    break
                }
            }
            DispatchQueue.main.async {
                self?.bonjourResults = devices
                // Merge with any existing results
                self?.mergeResults()
            }
        }
        
        smbBrowser.start(queue: .global(qos: .utility))
        self.browser = smbBrowser
        
        // Phase 2: Also try common NAS hostnames as fallback (in case Bonjour is blocked)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let commonHosts = [
                "synology.local", "qnap.local", "freenas.local",
                "truenas.local", "nas.local", "unraid.local",
                "openmediavault.local", "asustor.local",
            ]
            
            var fallbackFound: [DiscoveredNAS] = []
            for hostname in commonHosts {
                if NetworkDetector.pingHost(hostname, timeout: 1) {
                    let name = hostname.replacingOccurrences(of: ".local", with: "")
                    let device = DiscoveredNAS(
                        hostname: hostname,
                        name: name,
                        serviceType: "_smb._tcp"
                    )
                    fallbackFound.append(device)
                }
            }
            
            DispatchQueue.main.async {
                // Merge fallback results with Bonjour results (deduplicate by hostname)
                let existing = Set(self?.discoveredDevices.map { $0.hostname } ?? [])
                for device in fallbackFound {
                    if !existing.contains(device.hostname) {
                        self?.discoveredDevices.append(device)
                    }
                }
                self?.discoveredDevices.sort { $0.name < $1.name }
            }
        }
        
        // Stop Bonjour scan after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.browser?.cancel()
            self?.browser = nil
        }
    }
    
    private func mergeResults() {
        let existing = Set(discoveredDevices.map { $0.hostname })
        for device in bonjourResults {
            if !existing.contains(device.hostname) {
                discoveredDevices.append(device)
            }
        }
        discoveredDevices.sort { $0.name < $1.name }
    }
}
