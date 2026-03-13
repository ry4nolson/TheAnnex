import Foundation

class RsyncWrapper {
    @discardableResult
    static func sync(
        from source: String,
        to destination: String,
        excludePatterns: [String] = [],
        dryRun: Bool = false,
        bandwidthLimit: Int? = nil,
        customFlags: [String] = [],
        progressHandler: ((RsyncProgress) -> Void)? = nil,
        rawOutputHandler: (([String]) -> Void)? = nil,
        completion: @escaping (RsyncResult) -> Void
    ) -> Process? {
        let destPath = destination.hasSuffix("/") ? String(destination.dropLast()) : destination
        let mkdirCommand = "mkdir -p \"\(destPath)\""
        let mkdirResult = ShellHelper.run(mkdirCommand)
        
        if !mkdirResult.isSuccess {
            completion(RsyncResult(
                success: false,
                bytesTransferred: 0,
                filesTransferred: 0,
                duration: 0,
                error: "Failed to create destination directory: \(mkdirResult.error ?? "Unknown error")"
            ))
            return nil
        }
        
        var args = ["-av", "--ignore-existing", "--stats", "--progress"]
        
        if dryRun {
            args.append("--dry-run")
        }
        
        if let limit = bandwidthLimit {
            args.append("--bwlimit=\(limit)")
        }
        
        for pattern in excludePatterns {
            args.append("--exclude=\(pattern)")
        }
        
        for flag in customFlags where !flag.isEmpty {
            args.append(flag)
        }
        
        args.append(contentsOf: [source.hasSuffix("/") ? source : source + "/", destination.hasSuffix("/") ? destination : destination + "/"])
        
        let command = "rsync " + args.map { arg in
            if arg.contains(" ") {
                return "\"\(arg)\""
            }
            return arg
        }.joined(separator: " ")
        
        var currentProgress = RsyncProgress()
        var lastFileBytes: Int64 = 0
        let startTime = Date()
        
        let process = ShellHelper.runAsync(command, outputHandler: { lines in
                // Process all lines in the batch for accurate counting
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }
                    
                    // Parse progress lines like: "  1,234,567  45%  123.45kB/s    0:00:12"
                    if trimmed.contains("%") && !trimmed.hasPrefix("building") {
                        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if let bytesStr = components.first,
                           let fileBytes = Int64(bytesStr.replacingOccurrences(of: ",", with: "")) {
                            if fileBytes < lastFileBytes {
                                currentProgress.bytesTransferred += lastFileBytes
                                lastFileBytes = fileBytes
                            } else {
                                lastFileBytes = fileBytes
                            }
                            currentProgress.currentBytesTransferred = currentProgress.bytesTransferred + lastFileBytes
                            currentProgress.transferRate = Date().timeIntervalSince(startTime) > 0
                                ? Double(currentProgress.currentBytesTransferred) / Date().timeIntervalSince(startTime)
                                : 0
                        }
                        continue
                    }
                    
                    // Skip summary/status lines
                    if trimmed.hasPrefix("sending") || trimmed.hasPrefix("sent") || 
                       trimmed.hasPrefix("total size") || trimmed.contains("speedup") ||
                       trimmed.hasPrefix("building file list") || trimmed.contains("to-check=") ||
                       trimmed.hasPrefix("Number of") || trimmed.hasPrefix("Transfer starting") ||
                       trimmed.hasPrefix("Total") || trimmed.hasPrefix("Unmatched") ||
                       trimmed.hasPrefix("Matched") || trimmed.hasPrefix("File list") ||
                       trimmed.hasPrefix("received") {
                        continue
                    }
                    
                    // File name / status lines
                    if trimmed.hasSuffix("/") {
                        currentProgress.bytesTransferred += lastFileBytes
                        lastFileBytes = 0
                        currentProgress.currentFile = trimmed
                    } else {
                        currentProgress.bytesTransferred += lastFileBytes
                        lastFileBytes = 0
                        currentProgress.currentFile = trimmed
                        currentProgress.filesTransferred += 1
                    }
                    currentProgress.currentBytesTransferred = currentProgress.bytesTransferred
                }
                
                // Call handlers once per batch, not per line
                rawOutputHandler?(lines)
                progressHandler?(currentProgress)
        }, completion: { result in
            let duration = Date().timeIntervalSince(startTime)
            
            // Finalize accumulated bytes from last file
            let finalBytes = currentProgress.bytesTransferred + lastFileBytes
            let finalFiles = currentProgress.filesTransferred
            
            if result.isSuccess {
                let stats = parseRsyncStats(result.output)
                // Use parsed stats if available, otherwise fall back to progress-tracked values
                let bytesResult = stats.bytesTransferred > 0 ? stats.bytesTransferred : finalBytes
                let filesResult = stats.filesTransferred > 0 ? stats.filesTransferred : finalFiles
                let rsyncResult = RsyncResult(
                    success: true,
                    bytesTransferred: bytesResult,
                    filesTransferred: filesResult,
                    duration: duration,
                    error: nil
                )
                completion(rsyncResult)
            } else {
                let rsyncResult = RsyncResult(
                    success: false,
                    bytesTransferred: finalBytes,
                    filesTransferred: finalFiles,
                    duration: duration,
                    error: result.error ?? "Rsync failed with exit code \(result.exitCode)"
                )
                completion(rsyncResult)
            }
        })
        
        return process
    }
    
    private static func parseRsyncStats(_ output: String) -> (bytesTransferred: Int64, filesTransferred: Int) {
        var bytes: Int64 = 0
        var files = 0
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Total transferred file size:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    let numberString = components[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ")[0]
                    bytes = Int64(numberString.replacingOccurrences(of: ",", with: "")) ?? 0
                }
            } else if line.contains("Number of regular files transferred:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    let numberString = components[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ")[0]
                    files = Int(numberString.replacingOccurrences(of: ",", with: "")) ?? 0
                }
            }
        }
        
        return (bytes, files)
    }
}

struct RsyncProgress {
    var currentFile: String?
    var filesTransferred: Int = 0
    var bytesTransferred: Int64 = 0
    var currentBytesTransferred: Int64 = 0
    var transferRate: Double = 0
}

struct RsyncResult {
    let success: Bool
    let bytesTransferred: Int64
    let filesTransferred: Int
    let duration: TimeInterval
    let error: String?
}
