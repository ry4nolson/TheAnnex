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
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return false }
        
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
            if let target = symlinkTarget(at: localPath), target == nasPath {
                return .failure(.alreadySymlinked(localPath))
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
                // Fallback: use shell mv for macOS-protected directories
                let result = ShellHelper.run("mv \"\(localPath)\" \"\(backup)\"")
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
            let lnResult = ShellHelper.run("ln -s \"\(nasPath)\" \"\(localPath)\"")
            if !lnResult.isSuccess {
                NSLog("[SYMLINK] Shell ln also failed for %@: %@", localPath, lnResult.error ?? lnResult.output)
                // Restore backup on failure
                if let backup = backupPath {
                    try? fm.moveItem(atPath: backup, toPath: localPath)
                    if !fm.fileExists(atPath: localPath) {
                        _ = ShellHelper.run("mv \"\(backup)\" \"\(localPath)\"")
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
            let rmResult = ShellHelper.run("rm \"\(localPath)\"")
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
                let mvResult = ShellHelper.run("mv \"\(backup)\" \"\(localPath)\"")
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
    
    /// Called when NAS goes offline: unsymlink all symlink-mode folders.
    func handleNASOffline(folders: [SyncFolder]) -> [(SyncFolder, Result<Void, SymlinkError>)] {
        var results: [(SyncFolder, Result<Void, SymlinkError>)] = []
        
        for folder in folders where folder.symlinkMode && folder.symlinkState == .symlinked {
            let result = removeSymlink(localPath: folder.localPath)
            results.append((folder, result))
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
