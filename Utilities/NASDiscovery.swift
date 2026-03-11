import Foundation
import Network

class NASDiscovery: NSObject, ObservableObject {
    @Published var discoveredDevices: [DiscoveredNAS] = []
    
    private var browser: NWBrowser?
    private var isScanning = false
    
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
                let hostname = "\(name).\(domain)"
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
        
        let commonHosts = [
            ("RyaNAS.local", "RyaNAS"),
            ("synology.local", "Synology NAS"),
            ("qnap.local", "QNAP NAS"),
            ("freenas.local", "FreeNAS"),
            ("truenas.local", "TrueNAS"),
            ("nas.local", "NAS"),
        ]
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var found: [DiscoveredNAS] = []
            
            for (hostname, name) in commonHosts {
                if NetworkDetector.pingHost(hostname, timeout: 1) {
                    let device = DiscoveredNAS(
                        hostname: hostname,
                        name: name,
                        serviceType: "smb"
                    )
                    found.append(device)
                }
            }
            
            DispatchQueue.main.async {
                self?.discoveredDevices = found
            }
        }
    }
}
