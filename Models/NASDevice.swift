import Foundation

struct NASDevice: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var hostname: String
    var username: String
    var shares: [String]
    var isDefault: Bool
    
    init(id: UUID = UUID(),
         name: String,
         hostname: String,
         username: String,
         shares: [String] = [],
         isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.username = username
        self.shares = shares
        self.isDefault = isDefault
    }
    
    var baseURL: String {
        "smb://\(username)@\(hostname)"
    }
    
    func shareURL(for share: String) -> String {
        "\(baseURL)/\(share)"
    }
    
    func authenticatedShareURL(for share: String) -> String {
        if let password = KeychainHelper.shared.get(for: "nas_\(id.uuidString)"),
           !password.isEmpty {
            let escapedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password
            return "smb://\(username):\(escapedPassword)@\(hostname)/\(share)"
        }
        return shareURL(for: share)
    }
    
    func sharePath(for share: String) -> String {
        "/Volumes/\(share)"
    }
}

struct DiscoveredNAS: Identifiable, Hashable {
    let id = UUID()
    let hostname: String
    let name: String
    let serviceType: String
    
    var displayName: String {
        name.isEmpty ? hostname : "\(name) (\(hostname))"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(hostname)
    }
    
    static func == (lhs: DiscoveredNAS, rhs: DiscoveredNAS) -> Bool {
        lhs.hostname == rhs.hostname
    }
}
