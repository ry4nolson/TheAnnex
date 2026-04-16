import Foundation

class SymlinkManager {
    
    enum SymlinkError: Error, CustomStringConvertible {
        case localPathNotFound(String)
        case nasPathNotFound(String)
        case alreadySymlinked(String)
        case notSymlinked(String)
        case backupFailed(String)
        case symlinkCreationFailed(String)
        case restoreFailed(String)
        case syncRequired(String)
        
        var description: String {
            switch self {
            case .localPathNotFound(let p): return "Local path not found: \(p)"
            case .nasPathNotFound(let p): return "NAS path not found: \(p)"
            case .alreadySymlinked(let p): return "Already symlinked: \(p)"
            case .notSymlinked(let p): return "Not a symlink: \(p)"
            case .backupFailed(let p): return "Backup failed: \(p)"
            case .symlinkCreationFailed(let p): return "Symlink creation failed: \(p)"
            case .restoreFailed(let p): return "Restore failed: \(p)"
            case .syncRequired(let p): return "Sync required before symlinking: \(p)"
            }
        }
    }
    
    static let shared = SymlinkManager()
    private let fm = FileManager.default
    
    private init() {}
    
    // MARK: - Query
    
    func isSymlink(at path: String) -> Bool {
        // Do not use fileExists first — it follows symlinks, so a dangling link to an offline NAS
        // incorrectly looks "not there" and we skip unsymlink/repair.
        do {
            let attrs = try fm.attributesOfItem(atPath: path)
            return attrs[.type] as? FileAttributeType == .typeSymbolicLink
        } catch {
            return false
        }
    }
    
    func symlinkTarget(at path: String) -> String? {
        guard isSymlink(at: path) else { return nil }
        return try? fm.destinationOfSymbolicLink(atPath: path)
    }
    
    /// Whether `localPath` is a symlink whose target is the configured NAS folder (or a path inside it).
    func localSymlinkMatchesConfiguredNASPath(_ folder: SyncFolder) -> Bool {
        guard isSymlink(at: folder.localPath), let target = symlinkTarget(at: folder.localPath) else { return false }
        func norm(_ p: String) -> String {
            var s = (p as NSString).standardizingPath
            while s.hasSuffix("/"), s.count > 1 { s.removeLast() }
            return s
        }
        let nas = norm(folder.nasPath)
        let dst = norm(target)
        if dst == nas { return true }
        if dst.hasPrefix(nas + "/") { return true }
        return false
    }
    
    // MARK: - Create Symlink (local → NAS)
    
    /// Replaces localPath with a symlink pointing to nasPath.
    /// Moves any existing local contents to a backup location first.
    /// Returns the backup path if contents were moved.
    func createSymlink(localPath: String, nasPath: String) -> Result<String?, SymlinkError> {
        // Safety: NAS path must exist and be accessible
        guard fm.fileExists(atPath: nasPath) else {
            return .failure(.nasPathNotFound(nasPath))
        }
        
        // Already a symlink?
        if isSymlink(at: localPath) {
            if let target = symlinkTarget(at: localPath) {
                let t = (target as NSString).standardizingPath
                let n = (nasPath as NSString).standardizingPath
                if t == n || t.hasPrefix(n + "/") {
                    // Idempotent — avoids SyncEngine marking .local while disk stays symlinked
                    return .success(nil)
                }
            }
            // Symlinked to something else — remove it
            try? fm.removeItem(atPath: localPath)
        }
        
        var backupPath: String? = nil
        
        // If local folder exists with contents, move to backup
        if fm.fileExists(atPath: localPath) {
            let backup = localPath + ".theannex-backup"
            
            // Remove stale backup if it exists
            if fm.fileExists(atPath: backup) {
                try? fm.removeItem(atPath: backup)
            }
            
            do {
                try fm.moveItem(atPath: localPath, toPath: backup)
                backupPath = backup
            } catch {
                NSLog("[SYMLINK] FileManager.moveItem failed for %@: %@, trying shell mv", localPath, error.localizedDescription)
                let result = ShellHelper.runDirect("/bin/mv", arguments: [localPath, backup])
                if result.isSuccess {
                    backupPath = backup
                } else {
                    NSLog("[SYMLINK] Shell mv also failed for %@: %@", localPath, result.error ?? result.output)
                    return .failure(.backupFailed("Failed to backup \(localPath): \(error.localizedDescription)"))
                }
            }
        }
        
        // Create the symlink
        do {
            try fm.createSymbolicLink(atPath: localPath, withDestinationPath: nasPath)
        } catch {
            NSLog("[SYMLINK] FileManager.createSymbolicLink failed for %@: %@, trying shell ln", localPath, error.localizedDescription)
            let lnResult = ShellHelper.runDirect("/bin/ln", arguments: ["-s", nasPath, localPath])
            if !lnResult.isSuccess {
                NSLog("[SYMLINK] Shell ln also failed for %@: %@", localPath, lnResult.error ?? lnResult.output)
                // Restore backup on failure
                if let backup = backupPath {
                    try? fm.moveItem(atPath: backup, toPath: localPath)
                    if !fm.fileExists(atPath: localPath) {
                        _ = ShellHelper.runDirect("/bin/mv", arguments: [backup, localPath])
                    }
                }
                return .failure(.symlinkCreationFailed("Failed to create symlink: \(error.localizedDescription)"))
            }
        }
        
        return .success(backupPath)
    }
    
    // MARK: - Remove Symlink (restore local folder)
    
    /// Removes the symlink at localPath and restores a real local directory.
    /// If a backup exists, it's moved back. Otherwise, an empty folder is created.
    func removeSymlink(localPath: String) -> Result<Void, SymlinkError> {
        guard isSymlink(at: localPath) else {
            // Not a symlink — might already be a real folder
            if fm.fileExists(atPath: localPath) {
                return .success(())
            }
            return .failure(.notSymlinked(localPath))
        }
        
        // Remove the symlink
        do {
            try fm.removeItem(atPath: localPath)
        } catch {
            NSLog("[SYMLINK] FileManager.removeItem failed for %@: %@, trying shell rm", localPath, error.localizedDescription)
            let rmResult = ShellHelper.runDirect("/bin/rm", arguments: [localPath])
            if !rmResult.isSuccess {
                return .failure(.restoreFailed("Failed to remove symlink: \(error.localizedDescription)"))
            }
        }
        
        // Restore backup if available
        let backup = localPath + ".theannex-backup"
        if fm.fileExists(atPath: backup) {
            do {
                try fm.moveItem(atPath: backup, toPath: localPath)
            } catch {
                NSLog("[SYMLINK] FileManager.moveItem restore failed for %@: %@, trying shell mv", localPath, error.localizedDescription)
                let mvResult = ShellHelper.runDirect("/bin/mv", arguments: [backup, localPath])
                if !mvResult.isSuccess {
                    // Both failed — create empty folder as fallback
                    try? fm.createDirectory(atPath: localPath, withIntermediateDirectories: true)
                    return .failure(.restoreFailed("Backup restore failed, created empty folder: \(error.localizedDescription)"))
                }
            }
        } else {
            // No backup — create empty folder
            do {
                try fm.createDirectory(atPath: localPath, withIntermediateDirectories: true)
            } catch {
                return .failure(.restoreFailed("Failed to create local folder: \(error.localizedDescription)"))
            }
        }
        
        return .success(())
    }
    
    // MARK: - Cleanup
    
    /// Removes the backup directory for a folder if it exists.
    func removeBackup(for localPath: String) {
        let backup = localPath + ".theannex-backup"
        try? fm.removeItem(atPath: backup)
    }
    
    /// Checks if a backup exists for a given local path.
    func hasBackup(for localPath: String) -> Bool {
        return fm.fileExists(atPath: localPath + ".theannex-backup")
    }
    
    // MARK: - Batch Operations
    
    /// Called when NAS goes offline: unsymlink symlink-mode folders that still point at the configured NAS path.
    /// Includes state desync (disk is symlinked but `symlinkState` is still `.local`).
    func handleNASOffline(folders: [SyncFolder]) -> [(SyncFolder, Result<Void, SymlinkError>)] {
        var results: [(SyncFolder, Result<Void, SymlinkError>)] = []
        
        for folder in folders where folder.symlinkMode && folder.symlinkState != .restoring {
            guard folder.symlinkState == .symlinked || folder.symlinkState == .local else { continue }
            guard localSymlinkMatchesConfiguredNASPath(folder) else { continue }
            let result = removeSymlink(localPath: folder.localPath)
            results.append((folder, result))
        }
        
        return results
    }
    
    /// Host(s) may still respond to ping while SMB shares are gone, or one of several NAS devices may be down.
    /// Removes symlinks when the configured `nasPath` is missing or the folder's `nasDeviceId` host is offline.
    func repairSymlinksWhenNASMayBePartiallyReachable(folders: [SyncFolder], perDeviceOnline: [UUID: Bool]) -> [(SyncFolder, Result<Void, SymlinkError>)] {
        var results: [(SyncFolder, Result<Void, SymlinkError>)] = []
        var handled = Set<UUID>()
        
        let offlineDevices = Set(perDeviceOnline.filter { !$0.value }.map { $0.key })
        
        for folder in folders {
            guard folder.symlinkMode, folder.symlinkState != .restoring else { continue }
            guard folder.symlinkState == .symlinked || folder.symlinkState == .local else { continue }
            guard !handled.contains(folder.id) else { continue }
            guard localSymlinkMatchesConfiguredNASPath(folder) else { continue }
            
            if let dev = folder.nasDeviceId, offlineDevices.contains(dev) {
                let result = removeSymlink(localPath: folder.localPath)
                results.append((folder, result))
                handled.insert(folder.id)
                continue
            }
            
            if !fm.fileExists(atPath: folder.nasPath) {
                let result = removeSymlink(localPath: folder.localPath)
                results.append((folder, result))
                handled.insert(folder.id)
            }
        }
        
        return results
    }
    
    /// Called when NAS comes online: after syncing, re-symlink all symlink-mode folders.
    func handleNASOnline(folder: SyncFolder) -> Result<String?, SymlinkError> {
        guard folder.symlinkMode else {
            return .success(nil)
        }
        
        return createSymlink(localPath: folder.localPath, nasPath: folder.nasPath)
    }
}
