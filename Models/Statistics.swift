import Foundation

struct Statistics: Codable {
    var totalBytesTransferred: Int64
    var totalFilesTransferred: Int
    var totalSyncs: Int
    var successfulSyncs: Int
    var failedSyncs: Int
    var lastSyncDate: Date?
    var syncHistory: [SyncHistoryEntry]
    
    init() {
        self.totalBytesTransferred = 0
        self.totalFilesTransferred = 0
        self.totalSyncs = 0
        self.successfulSyncs = 0
        self.failedSyncs = 0
        self.lastSyncDate = nil
        self.syncHistory = []
    }
    
    mutating func recordSync(folderId: UUID, folderName: String, bytesTransferred: Int64, filesTransferred: Int, duration: TimeInterval, success: Bool) {
        totalSyncs += 1
        if success {
            successfulSyncs += 1
            totalBytesTransferred += bytesTransferred
            totalFilesTransferred += filesTransferred
        } else {
            failedSyncs += 1
        }
        lastSyncDate = Date()
        
        let entry = SyncHistoryEntry(
            folderId: folderId,
            folderName: folderName,
            date: Date(),
            bytesTransferred: bytesTransferred,
            filesTransferred: filesTransferred,
            duration: duration,
            success: success
        )
        syncHistory.append(entry)
        
        if syncHistory.count > 1000 {
            syncHistory.removeFirst(syncHistory.count - 1000)
        }
    }
    
    var formattedTotalBytes: String {
        ByteCountFormatter.string(fromByteCount: totalBytesTransferred, countStyle: .file)
    }
    
    var successRate: Double {
        guard totalSyncs > 0 else { return 0.0 }
        return Double(successfulSyncs) / Double(totalSyncs)
    }
}

struct SyncHistoryEntry: Codable, Identifiable {
    let id: UUID
    let folderId: UUID
    let folderName: String
    let date: Date
    let bytesTransferred: Int64
    let filesTransferred: Int
    let duration: TimeInterval
    let success: Bool
    
    init(id: UUID = UUID(),
         folderId: UUID,
         folderName: String,
         date: Date,
         bytesTransferred: Int64,
         filesTransferred: Int,
         duration: TimeInterval,
         success: Bool) {
        self.id = id
        self.folderId = folderId
        self.folderName = folderName
        self.date = date
        self.bytesTransferred = bytesTransferred
        self.filesTransferred = filesTransferred
        self.duration = duration
        self.success = success
    }
    
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: bytesTransferred, countStyle: .file)
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var averageSpeed: Double {
        guard duration > 0 else { return 0 }
        return Double(bytesTransferred) / duration
    }
    
    var formattedSpeed: String {
        let bytesPerSecond = averageSpeed
        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }
}
