import Foundation

class SyncJob: Identifiable, ObservableObject {
    let id: UUID
    let folderId: UUID
    let folderName: String
    @Published var state: SyncJobState
    @Published var progress: Double
    @Published var currentFile: String?
    @Published var bytesTransferred: Int64
    @Published var totalBytes: Int64
    @Published var filesTransferred: Int
    @Published var totalFiles: Int
    @Published var transferSpeed: Double
    @Published var estimatedTimeRemaining: TimeInterval?
    @Published var error: String?
    let startDate: Date
    @Published var endDate: Date?
    var process: Process?
    
    init(folderId: UUID, folderName: String) {
        self.id = UUID()
        self.folderId = folderId
        self.folderName = folderName
        self.state = .queued
        self.progress = 0.0
        self.currentFile = nil
        self.bytesTransferred = 0
        self.totalBytes = 0
        self.filesTransferred = 0
        self.totalFiles = 0
        self.transferSpeed = 0.0
        self.estimatedTimeRemaining = nil
        self.error = nil
        self.startDate = Date()
        self.endDate = nil
    }
    
    var duration: TimeInterval {
        if let endDate = endDate {
            return endDate.timeIntervalSince(startDate)
        }
        return Date().timeIntervalSince(startDate)
    }
}

enum SyncJobState: String {
    case queued
    case running
    case paused
    case completed
    case failed
    case cancelled
}
