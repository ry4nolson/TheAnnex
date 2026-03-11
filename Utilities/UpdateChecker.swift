import Foundation
#if canImport(Cocoa)
import Cocoa
#endif

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    
    @Published var latestVersion: String?
    @Published var downloadURL: String?
    @Published var isChecking = false
    @Published var updateAvailable = false
    @Published var lastCheckError: String?
    
    private let repoOwner = "ry4nolson"
    private let repoName = "TheAnnex"
    
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
    
    private init() {}
    
    func checkForUpdates(completion: ((Bool) -> Void)? = nil) {
        guard !isChecking else {
            completion?(false)
            return
        }
        
        DispatchQueue.main.async {
            self.isChecking = true
            self.lastCheckError = nil
        }
        
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isChecking = false
                self.lastCheckError = "Invalid URL"
            }
            completion?(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isChecking = false
                    self.lastCheckError = error.localizedDescription
                }
                completion?(false)
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.isChecking = false
                    self.lastCheckError = "No data received"
                }
                completion?(false)
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    DispatchQueue.main.async {
                        self.isChecking = false
                        self.lastCheckError = "Invalid response"
                    }
                    completion?(false)
                    return
                }
                
                let tagName = json["tag_name"] as? String ?? ""
                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                let htmlURL = json["html_url"] as? String ?? "https://github.com/\(self.repoOwner)/\(self.repoName)/releases/latest"
                
                // Find .app.zip or .dmg asset URL
                var assetURL = htmlURL
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           let browserURL = asset["browser_download_url"] as? String,
                           (name.hasSuffix(".app.zip") || name.hasSuffix(".dmg") || name.hasSuffix(".zip")) {
                            assetURL = browserURL
                            break
                        }
                    }
                }
                
                let hasUpdate = self.isNewerVersion(version, than: self.currentVersion)
                
                DispatchQueue.main.async {
                    self.latestVersion = version
                    self.downloadURL = assetURL
                    self.updateAvailable = hasUpdate
                    self.isChecking = false
                }
                completion?(hasUpdate)
                
            } catch {
                DispatchQueue.main.async {
                    self.isChecking = false
                    self.lastCheckError = "Parse error: \(error.localizedDescription)"
                }
                completion?(false)
            }
        }.resume()
    }
    
    func openDownloadPage() {
        let urlString = downloadURL ?? "https://github.com/\(repoOwner)/\(repoName)/releases/latest"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Compares semver strings. Returns true if `version` is newer than `current`.
    func isNewerVersion(_ version: String, than current: String) -> Bool {
        let v1 = version.split(separator: ".").compactMap { Int($0) }
        let v2 = current.split(separator: ".").compactMap { Int($0) }
        
        let count = max(v1.count, v2.count)
        for i in 0..<count {
            let a = i < v1.count ? v1[i] : 0
            let b = i < v2.count ? v2[i] : 0
            if a > b { return true }
            if a < b { return false }
        }
        return false
    }
}
