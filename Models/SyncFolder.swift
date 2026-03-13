import Foundation

enum SymlinkState: String, Codable, Equatable, Hashable {
    case local       // Normal local folder, no symlink active
    case symlinked   // Local path is a symlink to NAS
    case restoring   // Transitioning: unsymlinking or re-symlinking
}

struct SyncFolder: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var localPath: String
    var nasPath: String
    var nasDeviceId: UUID?
    var isEnabled: Bool
    var excludePatterns: [String]
    var lastSyncDate: Date?
    var symlinkMode: Bool
    var symlinkState: SymlinkState
    var symlinkProtected: Bool
    
    init(id: UUID = UUID(),
         name: String,
         localPath: String,
         nasPath: String,
         nasDeviceId: UUID? = nil,
         isEnabled: Bool = true,
         excludePatterns: [String] = SyncFolder.defaultExcludePatterns,
         lastSyncDate: Date? = nil,
         symlinkMode: Bool = true,
         symlinkState: SymlinkState = .local,
         symlinkProtected: Bool = false) {
        self.id = id
        self.name = name
        self.localPath = localPath
        self.nasPath = nasPath
        self.nasDeviceId = nasDeviceId
        self.isEnabled = isEnabled
        self.excludePatterns = excludePatterns
        self.lastSyncDate = lastSyncDate
        self.symlinkMode = symlinkMode
        self.symlinkState = symlinkState
        self.symlinkProtected = symlinkProtected
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        localPath = try container.decode(String.self, forKey: .localPath)
        nasPath = try container.decode(String.self, forKey: .nasPath)
        nasDeviceId = try container.decodeIfPresent(UUID.self, forKey: .nasDeviceId)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        excludePatterns = try container.decode([String].self, forKey: .excludePatterns)
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate)
        symlinkMode = try container.decodeIfPresent(Bool.self, forKey: .symlinkMode) ?? true
        symlinkState = try container.decodeIfPresent(SymlinkState.self, forKey: .symlinkState) ?? .local
        symlinkProtected = try container.decodeIfPresent(Bool.self, forKey: .symlinkProtected) ?? false
    }
    
    static let defaultExcludePatterns = [
        ".DS_Store",
        ".Spotlight-V100",
        ".Trashes",
        ".fseventsd",
        ".TemporaryItems",
        "*.tmp",
        "*.temp",
        ".localized"
    ]
    
    static let presets: [SyncFolder] = [
        SyncFolder(
            name: "Downloads",
            localPath: NSHomeDirectory() + "/Downloads",
            nasPath: "/Volumes/home/Downloads"
        ),
        SyncFolder(
            name: "Documents",
            localPath: NSHomeDirectory() + "/Documents",
            nasPath: "/Volumes/home/Documents"
        ),
        SyncFolder(
            name: "Pictures",
            localPath: NSHomeDirectory() + "/Pictures",
            nasPath: "/Volumes/home/Pictures"
        ),
        SyncFolder(
            name: "Movies",
            localPath: NSHomeDirectory() + "/Movies",
            nasPath: "/Volumes/Plex/Movies"
        ),
        SyncFolder(
            name: "Music",
            localPath: NSHomeDirectory() + "/Music",
            nasPath: "/Volumes/home/Music"
        ),
        SyncFolder(
            name: "Desktop",
            localPath: NSHomeDirectory() + "/Desktop",
            nasPath: "/Volumes/home/Desktop"
        )
    ]
}
