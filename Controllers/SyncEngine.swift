import Foundation
import Combine

class SyncEngine: ObservableObject {
    static let shared = SyncEngine()
    
    @Published var activeSyncJobs: [SyncJob] = []
    @Published var syncQueue: [UUID] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let maxConcurrentSyncs = 2
    private var currentSyncs = 0
    private let syncQueue_lock = NSLock()
    private var _internalQueue: [UUID] = []
    private var _internalActiveIds: Set<UUID> = []
    
    var onLog: ((ActivityEntry) -> Void)?
    
    private init() {}
    
    func queueSync(for folder: SyncFolder) {
        syncQueue_lock.lock()
        
        if !_internalQueue.contains(folder.id) && !_internalActiveIds.contains(folder.id) {
            _internalQueue.append(folder.id)
            syncQueue_lock.unlock()
            
            log(.info, category: .sync, message: "Queued sync for \(folder.name)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.syncQueue_lock.lock()
                let snapshot = self._internalQueue
                self.syncQueue_lock.unlock()
                self.syncQueue = snapshot
            }
            
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
    
    func cancelAll() {
        syncQueue_lock.lock()
        let jobs = activeSyncJobs
        _internalQueue.removeAll()
        _internalActiveIds.removeAll()
        currentSyncs = 0
        syncQueue_lock.unlock()
        
        for job in jobs where job.state == .running || job.state == .queued {
            job.state = .cancelled
            job.endDate = Date()
            log(.info, category: .sync, message: "Cancelling sync for \(job.folderName)")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.syncQueue.removeAll()
            self?.activeSyncJobs.removeAll()
        }
        
        // Terminate processes off main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for job in jobs {
                if let process = job.process, process.isRunning {
                    process.terminate()
                }
            }
            self?.log(.info, category: .sync, message: "All syncs cancelled")
        }
    }
    
    func cancelSync(jobId: UUID) {
        if let job = activeSyncJobs.first(where: { $0.id == jobId }) {
            let folderName = job.folderName
            
            job.state = .cancelled
            job.endDate = Date()
            
            syncQueue_lock.lock()
            currentSyncs = max(0, currentSyncs - 1)
            _internalActiveIds.remove(job.folderId)
            syncQueue_lock.unlock()
            
            DispatchQueue.main.async { [weak self] in
                self?.activeSyncJobs.removeAll { $0.id == jobId }
            }
            
            // Everything else off main thread — log, terminate, processQueue
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.log(.info, category: .sync, message: "Cancelled sync for \(folderName)")
                if let process = job.process, process.isRunning {
                    process.terminate()
                }
                self?.processQueue()
            }
        }
    }
    
    private func processQueue() {
        syncQueue_lock.lock()
        let queueCount = _internalQueue.count
        let currentCount = currentSyncs
        syncQueue_lock.unlock()
        
        log(.info, category: .sync, message: "Processing queue: \(queueCount) queued, \(currentCount)/\(maxConcurrentSyncs) active")
        
        syncQueue_lock.lock()
        while currentSyncs < maxConcurrentSyncs && !_internalQueue.isEmpty {
            let folderId = _internalQueue.removeFirst()
            syncQueue_lock.unlock()
            
            log(.info, category: .sync, message: "Starting sync from queue")
            startSync(folderId: folderId)
            
            syncQueue_lock.lock()
        }
        let snapshot = _internalQueue
        syncQueue_lock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            self?.syncQueue = snapshot
        }
    }
    
    private func startSync(folderId: UUID) {
        guard let folder = AppState.shared.syncFolders.first(where: { $0.id == folderId }) else {
            log(.error, category: .sync, message: "Folder not found for sync: \(folderId)")
            return
        }
        
        syncQueue_lock.lock()
        currentSyncs += 1
        _internalActiveIds.insert(folder.id)
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
            let customFlags = AppState.shared.customRsyncFlags
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            
            let process = RsyncWrapper.sync(
            from: folder.localPath,
            to: folder.nasPath,
            excludePatterns: folder.excludePatterns,
            dryRun: false,
            bandwidthLimit: bandwidthLimit,
            customFlags: customFlags,
            progressHandler: { [weak job] progress in
                guard let job = job, job.state == .running else { return }
                DispatchQueue.main.async {
                    job.currentFile = progress.currentFile
                    job.filesTransferred = progress.filesTransferred
                    job.bytesTransferred = progress.currentBytesTransferred
                    job.transferSpeed = progress.transferRate
                }
            },
            rawOutputHandler: { [weak job] lines in
                guard let job = job, job.state == .running else { return }
                DispatchQueue.main.async {
                    job.rawLog.append(contentsOf: lines)
                    if job.rawLog.count > 500 {
                        job.rawLog.removeFirst(job.rawLog.count - 500)
                    }
                }
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                
                // If the job was cancelled, don't overwrite its state
                if job.state == .cancelled {
                    return
                }
                
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
                self.currentSyncs = max(0, self.currentSyncs - 1)
                self._internalActiveIds.remove(folder.id)
                self.syncQueue_lock.unlock()
                
                self.log(.info, category: .sync, message: "Recording statistics for \(folder.name)")
                
                DispatchQueue.main.async {
                    AppState.shared.statistics.recordSync(
                        folderId: folder.id,
                        folderName: folder.name,
                        bytesTransferred: result.bytesTransferred,
                        filesTransferred: result.filesTransferred,
                        duration: job.duration,
                        success: result.success
                    )
                    AppState.shared.saveStatistics()
                    self.log(.info, category: .sync, message: "Statistics saved: totalSyncs=\(AppState.shared.statistics.totalSyncs), totalFiles=\(AppState.shared.statistics.totalFilesTransferred)")
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
                                            let errorDesc = "\(error)"
                                            if errorDesc.contains("permission") || errorDesc.contains("Permission") || errorDesc.contains("not permitted") {
                                                final_.symlinkMode = false
                                                final_.symlinkState = .local
                                                final_.symlinkProtected = true
                                                self.log(.info, category: .sync, message: "Disabled symlink mode for \(folderName) — macOS protects this folder from being moved. Sync-only mode will be used instead.")
                                            } else {
                                                final_.symlinkState = .local
                                                self.log(.error, category: .sync, message: "Symlink failed for \(folderName): \(error)")
                                            }
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
