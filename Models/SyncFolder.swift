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
    var syncSchedule: SyncSchedule?
    var fileFilters: FileFilters?
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
         syncSchedule: SyncSchedule? = nil,
         fileFilters: FileFilters? = nil,
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
        self.syncSchedule = syncSchedule
        self.fileFilters = fileFilters
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
        syncSchedule = try container.decodeIfPresent(SyncSchedule.self, forKey: .syncSchedule)
        fileFilters = try container.decodeIfPresent(FileFilters.self, forKey: .fileFilters)
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

struct SyncSchedule: Codable, Equatable, Hashable {
    var startHour: Int
    var endHour: Int
    var daysOfWeek: [Int]
    var onlyOnWiFi: Bool
    var wifiSSIDs: [String]
    var onlyOnACPower: Bool
    
    init(startHour: Int = 0,
         endHour: Int = 24,
         daysOfWeek: [Int] = [0, 1, 2, 3, 4, 5, 6],
         onlyOnWiFi: Bool = false,
         wifiSSIDs: [String] = [],
         onlyOnACPower: Bool = false) {
        self.startHour = startHour
        self.endHour = endHour
        self.daysOfWeek = daysOfWeek
        self.onlyOnWiFi = onlyOnWiFi
        self.wifiSSIDs = wifiSSIDs
        self.onlyOnACPower = onlyOnACPower
    }
}

struct FileFilters: Codable, Equatable, Hashable {
    var allowedExtensions: [String]
    var maxFileSizeGB: Double?
    var minFileSizeKB: Double?
    
    init(allowedExtensions: [String] = [],
         maxFileSizeGB: Double? = nil,
         minFileSizeKB: Double? = nil) {
        self.allowedExtensions = allowedExtensions
        self.maxFileSizeGB = maxFileSizeGB
        self.minFileSizeKB = minFileSizeKB
    }
}
