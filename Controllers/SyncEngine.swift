import Foundation
import Combine

class SyncEngine: ObservableObject {
    static let shared = SyncEngine()
    
    @Published var activeSyncJobs: [SyncJob] = []
    @Published var syncQueue: [UUID] = []
    @Published var isPaused: Bool = false
    @Published var statistics = Statistics()
    
    private var cancellables = Set<AnyCancellable>()
    private let maxConcurrentSyncs = 2
    private var currentSyncs = 0
    private let syncQueue_lock = NSLock()
    
    var onLog: ((ActivityEntry) -> Void)?
    
    private init() {}
    
    func queueSync(for folder: SyncFolder) {
        syncQueue_lock.lock()
        
        if !syncQueue.contains(folder.id) && !activeSyncJobs.contains(where: { $0.folderId == folder.id }) {
            syncQueue.append(folder.id)
            log(.info, category: .sync, message: "Queued sync for \(folder.name)")
            syncQueue_lock.unlock()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.processQueue()
            }
        } else {
            syncQueue_lock.unlock()
        }
    }
    
    func queueSyncAll(folders: [SyncFolder]) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for folder in folders where folder.isEnabled {
                self?.queueSync(for: folder)
            }
        }
    }
    
    func pauseAll() {
        isPaused = true
        
        for job in activeSyncJobs {
            if let process = job.process, process.isRunning {
                process.terminate()
                job.state = .paused
                log(.info, category: .sync, message: "Pausing sync for \(job.folderName)")
            }
        }
        
        log(.info, category: .sync, message: "All syncs paused")
    }
    
    func resumeAll() {
        isPaused = false
        
        for job in activeSyncJobs where job.state == .paused {
            syncQueue_lock.lock()
            if !syncQueue.contains(job.folderId) {
                syncQueue.insert(job.folderId, at: 0)
            }
            syncQueue_lock.unlock()
            
            DispatchQueue.main.async { [weak self] in
                if let index = self?.activeSyncJobs.firstIndex(where: { $0.id == job.id }) {
                    self?.activeSyncJobs.remove(at: index)
                }
            }
            
            syncQueue_lock.lock()
            currentSyncs -= 1
            syncQueue_lock.unlock()
        }
        
        log(.info, category: .sync, message: "Syncs resumed")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processQueue()
        }
    }
    
    func cancelSync(jobId: UUID) {
        if let index = activeSyncJobs.firstIndex(where: { $0.id == jobId }) {
            let job = activeSyncJobs[index]
            
            if let process = job.process, process.isRunning {
                process.terminate()
                log(.info, category: .sync, message: "Terminating rsync process for \(job.folderName)")
            }
            
            job.state = .cancelled
            job.endDate = Date()
            activeSyncJobs.remove(at: index)
            
            syncQueue_lock.lock()
            currentSyncs -= 1
            syncQueue_lock.unlock()
            
            log(.info, category: .sync, message: "Cancelled sync for \(job.folderName)")
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.processQueue()
            }
        }
    }
    
    private func processQueue() {
        guard !isPaused else {
            log(.info, category: .sync, message: "Sync queue paused")
            return
        }
        
        syncQueue_lock.lock()
        let queueCount = syncQueue.count
        let currentCount = currentSyncs
        syncQueue_lock.unlock()
        
        log(.info, category: .sync, message: "Processing queue: \(queueCount) queued, \(currentCount)/\(maxConcurrentSyncs) active")
        
        syncQueue_lock.lock()
        while currentSyncs < maxConcurrentSyncs && !syncQueue.isEmpty {
            let folderId = syncQueue.removeFirst()
            syncQueue_lock.unlock()
            
            log(.info, category: .sync, message: "Starting sync from queue")
            startSync(folderId: folderId)
            
            syncQueue_lock.lock()
        }
        syncQueue_lock.unlock()
    }
    
    private func startSync(folderId: UUID) {
        guard let folder = AppState.shared.syncFolders.first(where: { $0.id == folderId }) else {
            log(.error, category: .sync, message: "Folder not found for sync: \(folderId)")
            return
        }
        
        syncQueue_lock.lock()
        currentSyncs += 1
        syncQueue_lock.unlock()
        
        let job = SyncJob(folderId: folder.id, folderName: folder.name)
        job.state = .running
        
        DispatchQueue.main.async { [weak self] in
            self?.activeSyncJobs.append(job)
        }
        
        log(.info, category: .sync, message: "Starting sync for \(folder.name)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Count files in parallel — don't block rsync start
            DispatchQueue.global(qos: .utility).async {
                let countCommand = "find \"\(folder.localPath)\" -type f | wc -l"
                let countResult = ShellHelper.run(countCommand)
                
                if countResult.isSuccess, let totalFiles = Int(countResult.output.trimmingCharacters(in: .whitespaces)) {
                    DispatchQueue.main.async {
                        job.totalFiles = totalFiles
                    }
                }
            }
            
            let bandwidthLimit = AppState.shared.bandwidthLimitKBps > 0 ? AppState.shared.bandwidthLimitKBps : nil
            
            let process = RsyncWrapper.sync(
            from: folder.localPath,
            to: folder.nasPath,
            excludePatterns: folder.excludePatterns,
            dryRun: false,
            bandwidthLimit: bandwidthLimit,
            progressHandler: { [weak job] progress in
                guard let job = job else { return }
                DispatchQueue.main.async {
                    job.currentFile = progress.currentFile
                    job.filesTransferred = progress.filesTransferred
                    job.bytesTransferred = progress.currentBytesTransferred
                    job.transferSpeed = progress.transferRate
                }
            },
            rawOutputHandler: { [weak job] line in
                guard let job = job else { return }
                DispatchQueue.main.async {
                    job.rawLog.append(line)
                    // Cap at 500 lines to avoid memory bloat
                    if job.rawLog.count > 500 {
                        job.rawLog.removeFirst(job.rawLog.count - 500)
                    }
                }
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                
                self.log(.info, category: .sync, message: "Sync completion handler called for \(folder.name): success=\(result.success), files=\(result.filesTransferred), bytes=\(result.bytesTransferred)")
                
                job.state = result.success ? .completed : .failed
                job.endDate = Date()
                job.bytesTransferred = result.bytesTransferred
                job.filesTransferred = result.filesTransferred
                job.error = result.error
                
                DispatchQueue.main.async {
                    if let index = self.activeSyncJobs.firstIndex(where: { $0.id == job.id }) {
                        self.activeSyncJobs.remove(at: index)
                    }
                }
                
                self.syncQueue_lock.lock()
                self.currentSyncs -= 1
                self.syncQueue_lock.unlock()
                
                self.log(.info, category: .sync, message: "Recording statistics for \(folder.name)")
                
                DispatchQueue.main.async {
                    self.statistics.recordSync(
                        folderId: folder.id,
                        folderName: folder.name,
                        bytesTransferred: result.bytesTransferred,
                        filesTransferred: result.filesTransferred,
                        duration: job.duration,
                        success: result.success
                    )
                    
                    self.log(.info, category: .sync, message: "Saving statistics to AppState")
                    AppState.shared.statistics = self.statistics
                    AppState.shared.saveStatistics()
                    self.log(.info, category: .sync, message: "Statistics saved: totalSyncs=\(self.statistics.totalSyncs), totalFiles=\(self.statistics.totalFilesTransferred)")
                }
                
                if result.success {
                    var message = "Completed sync for \(folder.name): \(result.filesTransferred) files, \(ByteCountFormatter.string(fromByteCount: result.bytesTransferred, countStyle: .file))"
                    if let quote = AnnexQuotes.shared.nextSyncCompleteQuote() {
                        message += " — \"\(quote)\""
                    }
                    self.log(.info, category: .sync, message: message)
                    
                    if var updatedFolder = AppState.shared.syncFolders.first(where: { $0.id == folder.id }) {
                        updatedFolder.lastSyncDate = Date()
                        
                        // Symlink mode: create symlink after successful sync (on background thread)
                        if updatedFolder.symlinkMode && updatedFolder.symlinkState == .local {
                            updatedFolder.symlinkState = .restoring
                            AppState.shared.updateSyncFolder(updatedFolder)
                            
                            let localPath = folder.localPath
                            let nasPath = folder.nasPath
                            let folderId = folder.id
                            let folderName = folder.name
                            
                            DispatchQueue.global(qos: .userInitiated).async {
                                self.log(.info, category: .sync, message: "Creating symlink for \(folderName): \(localPath) → \(nasPath)")
                                let symlinkResult = SymlinkManager.shared.createSymlink(localPath: localPath, nasPath: nasPath)
                                
                                DispatchQueue.main.async {
                                    if var final_ = AppState.shared.syncFolders.first(where: { $0.id == folderId }) {
                                        switch symlinkResult {
                                        case .success(let backupPath):
                                            final_.symlinkState = .symlinked
                                            self.log(.info, category: .sync, message: "Symlinked \(folderName) → \(nasPath)")
                                            if backupPath != nil {
                                                DispatchQueue.global(qos: .utility).async {
                                                    SymlinkManager.shared.removeBackup(for: localPath)
                                                }
                                            }
                                        case .failure(let error):
                                            final_.symlinkState = .local
                                            self.log(.error, category: .sync, message: "Symlink failed for \(folderName): \(error)")
                                        }
                                        AppState.shared.updateSyncFolder(final_)
                                    }
                                }
                            }
                        } else {
                            AppState.shared.updateSyncFolder(updatedFolder)
                        }
                    }
                } else {
                    var message = "Failed sync for \(folder.name): \(result.error ?? "Unknown error")"
                    if let quote = AnnexQuotes.shared.quote(AnnexQuotes.syncFailed) {
                        message += " — \"\(quote)\""
                    }
                    self.log(.error, category: .sync, message: message)
                }
                
                self.processQueue()
            }
        )
            
            job.process = process
        }
    }
    
    private func log(_ level: LogLevel, category: LogCategory, message: String, details: String? = nil) {
        let entry = ActivityEntry(level: level, category: category, message: message, details: details)
        onLog?(entry)
    }
}
