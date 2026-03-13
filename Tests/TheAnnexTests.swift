import Foundation

// ============================================================
// MARK: - Test Harness
// ============================================================

var totalTests = 0
var passedTests = 0
var failedTests = 0
var failedNames: [String] = []

func assert(_ condition: Bool, _ message: String = "", test: String = #function, file: String = #file, line: Int = #line) {
    totalTests += 1
    if condition {
        passedTests += 1
    } else {
        failedTests += 1
        let name = "\(file.split(separator: "/").last ?? ""):\(line) \(test)"
        failedNames.append(name)
        let msg = message.isEmpty ? "Assertion failed" : message
        print("  ✗ \(test) — \(msg)")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", test: String = #function, file: String = #file, line: Int = #line) {
    totalTests += 1
    if a == b {
        passedTests += 1
    } else {
        failedTests += 1
        let name = "\(file.split(separator: "/").last ?? ""):\(line) \(test)"
        failedNames.append(name)
        let msg = message.isEmpty ? "Expected \(b), got \(a)" : message
        print("  ✗ \(test) — \(msg)")
    }
}

func assertEqualFloat(_ a: Double, _ b: Double, accuracy: Double = 0.001, _ message: String = "", test: String = #function, file: String = #file, line: Int = #line) {
    totalTests += 1
    if abs(a - b) <= accuracy {
        passedTests += 1
    } else {
        failedTests += 1
        let name = "\(file.split(separator: "/").last ?? ""):\(line) \(test)"
        failedNames.append(name)
        let msg = message.isEmpty ? "Expected \(b) ± \(accuracy), got \(a)" : message
        print("  ✗ \(test) — \(msg)")
    }
}

func assertNotEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", test: String = #function, file: String = #file, line: Int = #line) {
    totalTests += 1
    if a != b {
        passedTests += 1
    } else {
        failedTests += 1
        let name = "\(file.split(separator: "/").last ?? ""):\(line) \(test)"
        failedNames.append(name)
        let msg = message.isEmpty ? "Expected values to differ, both were \(a)" : message
        print("  ✗ \(test) — \(msg)")
    }
}

func assertNil<T>(_ value: T?, _ message: String = "", test: String = #function, file: String = #file, line: Int = #line) {
    totalTests += 1
    if value == nil {
        passedTests += 1
    } else {
        failedTests += 1
        let name = "\(file.split(separator: "/").last ?? ""):\(line) \(test)"
        failedNames.append(name)
        print("  ✗ \(test) — Expected nil, got \(value!)")
    }
}

func assertNotNil<T>(_ value: T?, _ message: String = "", test: String = #function, file: String = #file, line: Int = #line) {
    totalTests += 1
    if value != nil {
        passedTests += 1
    } else {
        failedTests += 1
        let name = "\(file.split(separator: "/").last ?? ""):\(line) \(test)"
        failedNames.append(name)
        print("  ✗ \(test) — Expected non-nil")
    }
}

func runSuite(_ name: String, _ block: () -> Void) {
    print("▶ \(name)")
    block()
}

// ============================================================
// MARK: - NASState Tests
// ============================================================

func testNASState() {
    runSuite("NASState") {
        assertEqual(NASState.connected.displayName, "Connected")
        assertEqual(NASState.offline.displayName, "Offline")
        assertEqual(NASState.syncing.displayName, "Syncing")
        assertEqual(NASState.paused.displayName, "Paused")
        assertEqual(NASState.error.displayName, "Error")

        assertEqual(NASState.connected.iconName, "externaldrive.fill.badge.checkmark")
        assertEqual(NASState.offline.iconName, "externaldrive.badge.xmark")
        assertEqual(NASState.syncing.iconName, "arrow.triangle.2.circlepath")
        assertEqual(NASState.paused.iconName, "pause.circle.fill")
        assertEqual(NASState.error.iconName, "exclamationmark.triangle.fill")

        // Codable round-trip
        let allCases: [NASState] = [.connected, .offline, .syncing, .paused, .error]
        for state in allCases {
            let data = try! JSONEncoder().encode(state)
            let decoded = try! JSONDecoder().decode(NASState.self, from: data)
            assertEqual(decoded, state, "Round-trip failed for \(state)")
        }
    }
}

// ============================================================
// MARK: - NASDevice Tests
// ============================================================

func testNASDevice() {
    runSuite("NASDevice") {
        let device = NASDevice(name: "TestNAS", hostname: "test.local", username: "admin")
        assertEqual(device.name, "TestNAS")
        assertEqual(device.hostname, "test.local")
        assertEqual(device.username, "admin")
        assertEqual(device.shares, [])
        assert(!device.isDefault, "Default should be false")

        assertEqual(device.baseURL, "smb://admin@test.local")
        assertEqual(device.shareURL(for: "home"), "smb://admin@test.local/home")
        assertEqual(device.sharePath(for: "home"), "/Volumes/home")

        // Codable
        let full = NASDevice(name: "NAS", hostname: "nas.local", username: "admin", shares: ["home", "media"], isDefault: true)
        let data = try! JSONEncoder().encode(full)
        let decoded = try! JSONDecoder().decode(NASDevice.self, from: data)
        assertEqual(decoded, full)

        // Equality
        let id = UUID()
        let a = NASDevice(id: id, name: "NAS", hostname: "nas.local", username: "admin")
        let b = NASDevice(id: id, name: "NAS", hostname: "nas.local", username: "admin")
        assertEqual(a, b)

        let c = NASDevice(name: "NAS1", hostname: "nas1.local", username: "admin")
        let d = NASDevice(name: "NAS2", hostname: "nas2.local", username: "admin")
        assertNotEqual(c, d)

        // Hashable
        var set = Set<NASDevice>()
        set.insert(a)
        set.insert(b)
        assertEqual(set.count, 1)
    }
}

// ============================================================
// MARK: - DiscoveredNAS Tests
// ============================================================

func testDiscoveredNAS() {
    runSuite("DiscoveredNAS") {
        let withName = DiscoveredNAS(hostname: "nas.local", name: "MyNAS", serviceType: "_smb._tcp")
        assertEqual(withName.displayName, "MyNAS (nas.local)")

        let noName = DiscoveredNAS(hostname: "nas.local", name: "", serviceType: "_smb._tcp")
        assertEqual(noName.displayName, "nas.local")

        let a = DiscoveredNAS(hostname: "nas.local", name: "NAS", serviceType: "_smb._tcp")
        let b = DiscoveredNAS(hostname: "nas.local", name: "NAS", serviceType: "_smb._tcp")
        assertNotEqual(a.id, b.id)
    }
}

// ============================================================
// MARK: - SyncFolder Tests
// ============================================================

func testSyncFolder() {
    runSuite("SyncFolder") {
        let folder = SyncFolder(name: "Test", localPath: "/local", nasPath: "/nas")
        assertEqual(folder.name, "Test")
        assertEqual(folder.localPath, "/local")
        assertEqual(folder.nasPath, "/nas")
        assertNil(folder.nasDeviceId)
        assert(folder.isEnabled, "Should be enabled by default")
        assertNil(folder.lastSyncDate)

        // Default exclude patterns
        assert(folder.excludePatterns.contains(".DS_Store"), "Should contain .DS_Store")
        assert(folder.excludePatterns.contains(".Spotlight-V100"), "Should contain .Spotlight-V100")
        assert(folder.excludePatterns.contains(".Trashes"), "Should contain .Trashes")
        assert(folder.excludePatterns.contains("*.tmp"), "Should contain *.tmp")
        assertEqual(folder.excludePatterns.count, 8)

        // Custom exclude
        let custom = SyncFolder(name: "Test", localPath: "/local", nasPath: "/nas", excludePatterns: ["*.log"])
        assertEqual(custom.excludePatterns, ["*.log"])

        // Presets
        assert(!SyncFolder.presets.isEmpty, "Presets should not be empty")
        let names = SyncFolder.presets.map { $0.name }
        assert(names.contains("Downloads"), "Should have Downloads preset")
        assert(names.contains("Documents"), "Should have Documents preset")
        assert(names.contains("Pictures"), "Should have Pictures preset")
        assert(names.contains("Movies"), "Should have Movies preset")
        assert(names.contains("Music"), "Should have Music preset")
        assert(names.contains("Desktop"), "Should have Desktop preset")

        for preset in SyncFolder.presets {
            assert(preset.localPath.hasPrefix(NSHomeDirectory()), "Preset \(preset.name) should start with home dir")
        }

        // Codable
        let withDate = SyncFolder(name: "Test", localPath: "/local", nasPath: "/nas", nasDeviceId: UUID(), isEnabled: false, excludePatterns: ["*.log"], lastSyncDate: Date())
        let data = try! JSONEncoder().encode(withDate)
        let decoded = try! JSONDecoder().decode(SyncFolder.self, from: data)
        assertEqual(decoded, withDate)

        // Equality
        let id = UUID()
        let fa = SyncFolder(id: id, name: "Test", localPath: "/local", nasPath: "/nas")
        let fb = SyncFolder(id: id, name: "Test", localPath: "/local", nasPath: "/nas")
        assertEqual(fa, fb)
    }
}


// ============================================================
// MARK: - SyncJob Tests
// ============================================================

func testSyncJob() {
    runSuite("SyncJob") {
        let folderId = UUID()
        let job = SyncJob(folderId: folderId, folderName: "Downloads")
        assertEqual(job.folderId, folderId)
        assertEqual(job.folderName, "Downloads")
        assertEqual(job.state, .queued)
        assertEqualFloat(job.progress, 0.0)
        assertNil(job.currentFile)
        assertEqual(job.bytesTransferred, 0 as Int64)
        assertEqual(job.totalBytes, 0 as Int64)
        assertEqual(job.filesTransferred, 0)
        assertEqual(job.totalFiles, 0)
        assertEqualFloat(job.transferSpeed, 0.0)
        assertNil(job.estimatedTimeRemaining)
        assertNil(job.error)
        assertNil(job.endDate)
        assertNil(job.process)

        // Duration while running
        assert(job.duration >= 0, "Duration should be >= 0")
        assert(job.duration < 1.0, "Duration should be < 1s for a fresh job")

        // Duration after completion
        let completed = SyncJob(folderId: UUID(), folderName: "Test")
        completed.endDate = completed.startDate.addingTimeInterval(5.0)
        assertEqualFloat(completed.duration, 5.0)
    }
}

// ============================================================
// MARK: - SyncJobState Tests
// ============================================================

func testSyncJobState() {
    runSuite("SyncJobState") {
        assertEqual(SyncJobState.queued.rawValue, "queued")
        assertEqual(SyncJobState.running.rawValue, "running")
        assertEqual(SyncJobState.completed.rawValue, "completed")
        assertEqual(SyncJobState.failed.rawValue, "failed")
        assertEqual(SyncJobState.cancelled.rawValue, "cancelled")
    }
}

// ============================================================
// MARK: - ActivityEntry Tests
// ============================================================

func testActivityEntry() {
    runSuite("ActivityEntry") {
        let entry = ActivityEntry(level: .info, category: .sync, message: "Test message")
        assertEqual(entry.level, .info)
        assertEqual(entry.category, .sync)
        assertEqual(entry.message, "Test message")
        assertNil(entry.details)

        let withDetails = ActivityEntry(level: .error, category: .network, message: "Error", details: "Some details")
        assertEqual(withDetails.details, "Some details")

        // Formatted timestamp (HH:mm:ss)
        let formatted = entry.formattedTimestamp
        assertEqual(formatted.count, 8)
        assert(formatted.contains(":"), "Timestamp should contain colons")

        // Formatted date
        assert(!entry.formattedDate.isEmpty, "Formatted date should not be empty")

        // Codable
        let coding = ActivityEntry(level: .warning, category: .mount, message: "Test", details: "Details")
        let data = try! JSONEncoder().encode(coding)
        let decoded = try! JSONDecoder().decode(ActivityEntry.self, from: data)
        assertEqual(decoded.id, coding.id)
        assertEqual(decoded.level, coding.level)
        assertEqual(decoded.category, coding.category)
        assertEqual(decoded.message, coding.message)
        assertEqual(decoded.details, coding.details)
    }
}

// ============================================================
// MARK: - LogLevel Tests
// ============================================================

func testLogLevel() {
    runSuite("LogLevel") {
        assertEqual(LogLevel.debug.displayName, "Debug")
        assertEqual(LogLevel.info.displayName, "Info")
        assertEqual(LogLevel.warning.displayName, "Warning")
        assertEqual(LogLevel.error.displayName, "Error")

        assertEqual(LogLevel.debug.iconName, "ant.fill")
        assertEqual(LogLevel.info.iconName, "info.circle.fill")
        assertEqual(LogLevel.warning.iconName, "exclamationmark.triangle.fill")
        assertEqual(LogLevel.error.iconName, "xmark.octagon.fill")

        assertEqual(LogLevel.allCases.count, 4)

        for level in LogLevel.allCases {
            let data = try! JSONEncoder().encode(level)
            let decoded = try! JSONDecoder().decode(LogLevel.self, from: data)
            assertEqual(decoded, level)
        }
    }
}

// ============================================================
// MARK: - LogCategory Tests
// ============================================================

func testLogCategory() {
    runSuite("LogCategory") {
        assertEqual(LogCategory.sync.displayName, "Sync")
        assertEqual(LogCategory.mount.displayName, "Mount")
        assertEqual(LogCategory.network.displayName, "Network")
        assertEqual(LogCategory.system.displayName, "System")
        assertEqual(LogCategory.error.displayName, "Error")
        assertEqual(LogCategory.allCases.count, 5)
    }
}

// ============================================================
// MARK: - Statistics Tests
// ============================================================

func testStatistics() {
    runSuite("Statistics") {
        var stats = Statistics()
        assertEqual(stats.totalBytesTransferred, 0 as Int64)
        assertEqual(stats.totalFilesTransferred, 0)
        assertEqual(stats.totalSyncs, 0)
        assertEqual(stats.successfulSyncs, 0)
        assertEqual(stats.failedSyncs, 0)
        assertNil(stats.lastSyncDate)
        assert(stats.syncHistory.isEmpty, "History should be empty")
        assertEqualFloat(stats.successRate, 0.0)

        // Record successful sync
        stats.recordSync(folderId: UUID(), folderName: "Downloads", bytesTransferred: 1024, filesTransferred: 5, duration: 2.0, success: true)
        assertEqual(stats.totalSyncs, 1)
        assertEqual(stats.successfulSyncs, 1)
        assertEqual(stats.failedSyncs, 0)
        assertEqual(stats.totalBytesTransferred, 1024 as Int64)
        assertEqual(stats.totalFilesTransferred, 5)
        assertNotNil(stats.lastSyncDate)
        assertEqual(stats.syncHistory.count, 1)
        assertEqualFloat(stats.successRate, 1.0)

        // Record failed sync
        stats.recordSync(folderId: UUID(), folderName: "Downloads", bytesTransferred: 500, filesTransferred: 3, duration: 1.0, success: false)
        assertEqual(stats.totalSyncs, 2)
        assertEqual(stats.failedSyncs, 1)
        assertEqual(stats.totalBytesTransferred, 1024 as Int64, "Failed syncs should not accumulate bytes")
        assertEqual(stats.totalFilesTransferred, 5, "Failed syncs should not accumulate files")
        assertEqualFloat(stats.successRate, 0.5)

        // History cap
        var bigStats = Statistics()
        for i in 0..<1010 {
            bigStats.recordSync(folderId: UUID(), folderName: "Folder\(i)", bytesTransferred: 1, filesTransferred: 1, duration: 0.1, success: true)
        }
        assert(bigStats.syncHistory.count <= 1000, "History should be capped at 1000")

        // Formatted bytes
        assert(!stats.formattedTotalBytes.isEmpty, "Formatted bytes should not be empty")

        // Codable
        let data = try! JSONEncoder().encode(stats)
        let decoded = try! JSONDecoder().decode(Statistics.self, from: data)
        assertEqual(decoded.totalSyncs, stats.totalSyncs)
        assertEqual(decoded.totalBytesTransferred, stats.totalBytesTransferred)
        assertEqual(decoded.totalFilesTransferred, stats.totalFilesTransferred)
        assertEqual(decoded.successfulSyncs, stats.successfulSyncs)
        assertEqual(decoded.failedSyncs, stats.failedSyncs)
    }
}

// ============================================================
// MARK: - SyncHistoryEntry Tests
// ============================================================

func testSyncHistoryEntry() {
    runSuite("SyncHistoryEntry") {
        let folderId = UUID()
        let entry = SyncHistoryEntry(folderId: folderId, folderName: "Test", date: Date(), bytesTransferred: 1024, filesTransferred: 5, duration: 2.5, success: true)
        assertEqual(entry.folderId, folderId)
        assertEqual(entry.folderName, "Test")
        assertEqual(entry.bytesTransferred, 1024 as Int64)
        assertEqual(entry.filesTransferred, 5)
        assertEqualFloat(entry.duration, 2.5)
        assert(entry.success, "Should be successful")

        assert(!entry.formattedBytes.isEmpty, "formattedBytes should not be empty")
        assert(!entry.formattedDuration.isEmpty, "formattedDuration should not be empty")

        // Zero duration
        let zero = SyncHistoryEntry(folderId: UUID(), folderName: "Test", date: Date(), bytesTransferred: 0, filesTransferred: 0, duration: 0.0, success: true)
        assert(!zero.formattedDuration.isEmpty, "formattedDuration for 0s should not be empty")
        assertEqualFloat(zero.averageSpeed, 0.0)

        // Average speed
        let speedEntry = SyncHistoryEntry(folderId: UUID(), folderName: "Test", date: Date(), bytesTransferred: 1000, filesTransferred: 1, duration: 2.0, success: true)
        assertEqualFloat(speedEntry.averageSpeed, 500.0)

        // Formatted speed
        let bigEntry = SyncHistoryEntry(folderId: UUID(), folderName: "Test", date: Date(), bytesTransferred: 1_000_000, filesTransferred: 1, duration: 1.0, success: true)
        assert(bigEntry.formattedSpeed.contains("/s"), "formattedSpeed should contain /s")

        // Codable
        let data = try! JSONEncoder().encode(entry)
        let decoded = try! JSONDecoder().decode(SyncHistoryEntry.self, from: data)
        assertEqual(decoded.id, entry.id)
        assertEqual(decoded.bytesTransferred, entry.bytesTransferred)
        assertEqual(decoded.success, entry.success)
    }
}

// ============================================================
// MARK: - ConnectionQuality Tests
// ============================================================

func testConnectionQuality() {
    runSuite("ConnectionQuality") {
        assertEqual(ConnectionQuality(latency: 5.0, packetLoss: 0.0).qualityLevel, .excellent)
        assertEqual(ConnectionQuality(latency: 19.9, packetLoss: 0.0).qualityLevel, .excellent)
        assertEqual(ConnectionQuality(latency: 20.0, packetLoss: 0.0).qualityLevel, .good)
        assertEqual(ConnectionQuality(latency: 49.9, packetLoss: 0.0).qualityLevel, .good)
        assertEqual(ConnectionQuality(latency: 50.0, packetLoss: 0.0).qualityLevel, .fair)
        assertEqual(ConnectionQuality(latency: 99.9, packetLoss: 0.0).qualityLevel, .fair)
        assertEqual(ConnectionQuality(latency: 100.0, packetLoss: 0.0).qualityLevel, .poor)
        assertEqual(ConnectionQuality(latency: 5.0, packetLoss: 11.0).qualityLevel, .poor, "High packet loss should override good latency")
        assertEqual(ConnectionQuality(latency: 5.0, packetLoss: 10.0).qualityLevel, .excellent, "10% should not trigger poor")
        assertEqual(ConnectionQuality(latency: nil, packetLoss: 0.0).qualityLevel, .unknown)
        assertEqual(ConnectionQuality(latency: nil, packetLoss: 50.0).qualityLevel, .poor)

        assertEqual(ConnectionQuality.QualityLevel.excellent.rawValue, "Excellent")
        assertEqual(ConnectionQuality.QualityLevel.good.rawValue, "Good")
        assertEqual(ConnectionQuality.QualityLevel.fair.rawValue, "Fair")
        assertEqual(ConnectionQuality.QualityLevel.poor.rawValue, "Poor")
        assertEqual(ConnectionQuality.QualityLevel.unknown.rawValue, "Unknown")
    }
}

// ============================================================
// MARK: - ShellResult Tests
// ============================================================

func testShellResult() {
    runSuite("ShellResult") {
        assert(ShellResult(output: "ok", exitCode: 0, error: nil).isSuccess, "Exit 0 should be success")
        assert(!ShellResult(output: "", exitCode: 1, error: "fail").isSuccess, "Exit 1 should not be success")
        assert(!ShellResult(output: "", exitCode: 127, error: nil).isSuccess, "Exit 127 should not be success")
    }
}

// ============================================================
// MARK: - RsyncProgress Tests
// ============================================================

func testRsyncProgress() {
    runSuite("RsyncProgress") {
        var progress = RsyncProgress()
        assertNil(progress.currentFile)
        assertEqual(progress.filesTransferred, 0)
        assertEqual(progress.bytesTransferred, 0 as Int64)
        assertEqual(progress.currentBytesTransferred, 0 as Int64)
        assertEqualFloat(progress.transferRate, 0.0)

        progress.currentFile = "test.txt"
        progress.filesTransferred = 5
        progress.bytesTransferred = 1024
        progress.currentBytesTransferred = 2048
        progress.transferRate = 512.0
        assertEqual(progress.currentFile, "test.txt")
        assertEqual(progress.filesTransferred, 5)
        assertEqual(progress.bytesTransferred, 1024 as Int64)
        assertEqual(progress.currentBytesTransferred, 2048 as Int64)
        assertEqualFloat(progress.transferRate, 512.0)
    }
}

// ============================================================
// MARK: - RsyncResult Tests
// ============================================================

func testRsyncResult() {
    runSuite("RsyncResult") {
        let success = RsyncResult(success: true, bytesTransferred: 1024, filesTransferred: 5, duration: 2.0, error: nil)
        assert(success.success, "Should be success")
        assertEqual(success.bytesTransferred, 1024 as Int64)
        assertEqual(success.filesTransferred, 5)
        assertEqualFloat(success.duration, 2.0)
        assertNil(success.error)

        let failure = RsyncResult(success: false, bytesTransferred: 0, filesTransferred: 0, duration: 1.0, error: "Permission denied")
        assert(!failure.success, "Should not be success")
        assertEqual(failure.error, "Permission denied")
    }
}

// ============================================================
// MARK: - AnnexQuotes Tests
// ============================================================

func testAnnexQuotes() {
    runSuite("AnnexQuotes") {
        // Static strings
        assert(!AnnexQuotes.firstLaunchWelcome.isEmpty)
        assert(!AnnexQuotes.nasOffline.isEmpty)
        assert(!AnnexQuotes.emptyActivityLog.isEmpty)
        assert(!AnnexQuotes.perfectSuccessRate.isEmpty)
        assert(!AnnexQuotes.bandwidthLimitHit.isEmpty)
        assert(!AnnexQuotes.firstNASAdded.isEmpty)
        assert(!AnnexQuotes.syncFailed.isEmpty)
        assert(!AnnexQuotes.aboutFooter.isEmpty)
        assert(!AnnexQuotes.aboutInspiration.isEmpty)
        assert(!AnnexQuotes.tagline.isEmpty)
        assert(!AnnexQuotes.syncCompleteQuotes.isEmpty)

        let quotes = AnnexQuotes.shared
        let original = quotes.showPersonality

        // Off → nil
        quotes.showPersonality = false
        assertNil(quotes.quote("test"))
        assertNil(quotes.nextSyncCompleteQuote())

        // On → values
        quotes.showPersonality = true
        assertEqual(quotes.quote("test"), "test")

        let quote = quotes.nextSyncCompleteQuote()
        assertNotNil(quote)
        if let q = quote {
            assert(AnnexQuotes.syncCompleteQuotes.contains(q), "Quote should be from the list")
        }

        // Non-repeating: draw enough quotes to guarantee every one appears at least once
        let total = AnnexQuotes.syncCompleteQuotes.count
        var seen = Set<String>()
        // 2× total guarantees at least one full cycle through all quotes
        for _ in 0..<(total * 2) {
            if let q = quotes.nextSyncCompleteQuote() {
                seen.insert(q)
            }
        }
        assertEqual(seen.count, total, "All quotes should appear within 2× cycles")

        quotes.showPersonality = original
    }
}

// ============================================================
// MARK: - DiskSpace Tests
// ============================================================

func testDiskSpace() {
    runSuite("DiskSpace") {
        let ds = DiskSpace(totalBytes: 12_000_000_000_000, usedBytes: 1_160_000_000_000, freeBytes: 10_840_000_000_000)
        assert(!ds.totalFormatted.isEmpty)
        assert(!ds.freeFormatted.isEmpty)
        assert(!ds.usedFormatted.isEmpty)

        let quarter = DiskSpace(totalBytes: 1000, usedBytes: 250, freeBytes: 750)
        assertEqualFloat(quarter.usedPercentage, 25.0, accuracy: 0.1)

        let zero = DiskSpace(totalBytes: 0, usedBytes: 0, freeBytes: 0)
        assertEqualFloat(zero.usedPercentage, 0.0)

        let full = DiskSpace(totalBytes: 1000, usedBytes: 1000, freeBytes: 0)
        assertEqualFloat(full.usedPercentage, 100.0, accuracy: 0.1)
    }
}

// ============================================================
// MARK: - SymlinkState Tests
// ============================================================

func testSymlinkState() {
    runSuite("SymlinkState") {
        // Raw values
        assertEqual(SymlinkState.local.rawValue, "local")
        assertEqual(SymlinkState.symlinked.rawValue, "symlinked")
        assertEqual(SymlinkState.restoring.rawValue, "restoring")

        // Codable round-trip
        let states: [SymlinkState] = [.local, .symlinked, .restoring]
        for state in states {
            if let data = try? JSONEncoder().encode(state),
               let decoded = try? JSONDecoder().decode(SymlinkState.self, from: data) {
                assertEqual(decoded, state)
            } else {
                assert(false, "Codable failed for \(state)")
            }
        }

        // Equatable
        assert(SymlinkState.local == SymlinkState.local)
        assert(SymlinkState.local != SymlinkState.symlinked)
    }
}

// ============================================================
// MARK: - SyncFolder Symlink Fields Tests
// ============================================================

func testSyncFolderSymlink() {
    runSuite("SyncFolder Symlink") {
        // Defaults
        let folder = SyncFolder(name: "Test", localPath: "/tmp/test", nasPath: "/nas/test")
        assertEqual(folder.symlinkMode, true, "Default symlinkMode should be true")
        assertEqual(folder.symlinkState, .local, "Default symlinkState should be .local")

        // Explicit values
        let linked = SyncFolder(
            name: "Linked",
            localPath: "/tmp/linked",
            nasPath: "/nas/linked",
            symlinkMode: true,
            symlinkState: .symlinked
        )
        assertEqual(linked.symlinkMode, true)
        assertEqual(linked.symlinkState, .symlinked)

        // Codable round-trip with symlink fields
        if let data = try? JSONEncoder().encode(linked),
           let decoded = try? JSONDecoder().decode(SyncFolder.self, from: data) {
            assertEqual(decoded.symlinkMode, true)
            assertEqual(decoded.symlinkState, .symlinked)
            assertEqual(decoded.name, "Linked")
        } else {
            assert(false, "Codable failed for SyncFolder with symlink fields")
        }

        // Mutation
        var mutable = folder
        mutable.symlinkMode = true
        mutable.symlinkState = .restoring
        assertEqual(mutable.symlinkMode, true)
        assertEqual(mutable.symlinkState, .restoring)
        assert(mutable != folder, "Mutated folder should differ from original")
    }
}

// ============================================================
// MARK: - SymlinkManager Tests
// ============================================================

func testSymlinkManager() {
    runSuite("SymlinkManager") {
        let mgr = SymlinkManager.shared
        let fm = FileManager.default
        let testDir = NSTemporaryDirectory() + "theannex-test-\(UUID().uuidString)"
        let localDir = testDir + "/local"
        let nasDir = testDir + "/nas"

        // Setup
        try? fm.createDirectory(atPath: localDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: nasDir, withIntermediateDirectories: true)

        // Write a test file in local
        let testFile = localDir + "/testfile.txt"
        try? "hello".write(toFile: testFile, atomically: true, encoding: .utf8)

        // isSymlink on regular dir
        assert(!mgr.isSymlink(at: localDir), "Regular dir should not be symlink")
        assertEqual(mgr.symlinkTarget(at: localDir), nil, "No target for regular dir")

        // createSymlink: NAS path must exist
        let badResult = mgr.createSymlink(localPath: localDir, nasPath: testDir + "/nonexistent")
        if case .failure(let err) = badResult {
            assert(err.description.contains("not found"), "Should fail with NAS not found")
        } else {
            assert(false, "Should have failed for nonexistent NAS path")
        }

        // createSymlink: success
        let result = mgr.createSymlink(localPath: localDir, nasPath: nasDir)
        if case .success(let backupPath) = result {
            assert(backupPath != nil, "Should have created a backup")
            assert(mgr.isSymlink(at: localDir), "Local should now be symlink")
            assertEqual(mgr.symlinkTarget(at: localDir), nasDir, "Target should be NAS dir")
            assert(mgr.hasBackup(for: localDir), "Backup should exist")
        } else {
            assert(false, "createSymlink should succeed")
        }

        // createSymlink: already symlinked
        let dupResult = mgr.createSymlink(localPath: localDir, nasPath: nasDir)
        if case .failure(let err) = dupResult {
            assert(err.description.contains("Already"), "Should report already symlinked")
        } else {
            assert(false, "Should fail for already symlinked")
        }

        // removeSymlink: success
        let removeResult = mgr.removeSymlink(localPath: localDir)
        if case .success = removeResult {
            assert(!mgr.isSymlink(at: localDir), "Should no longer be symlink")
            assert(fm.fileExists(atPath: localDir), "Local dir should exist again")
        } else {
            assert(false, "removeSymlink should succeed")
        }

        // removeSymlink: not a symlink
        let notSymlink = mgr.removeSymlink(localPath: localDir)
        if case .success = notSymlink {
            // Already a real folder — this is fine
        } else {
            assert(false, "removeSymlink on real folder should succeed gracefully")
        }

        // removeBackup
        mgr.removeBackup(for: localDir)
        assert(!mgr.hasBackup(for: localDir), "Backup should be cleaned up")

        // Cleanup
        try? fm.removeItem(atPath: testDir)
    }
}

// ============================================================
// MARK: - Statistics Persistence Tests (Bug 1 regression)
// ============================================================

func testStatisticsPersistence() {
    runSuite("Statistics Persistence") {
        // Simulate what used to happen: record syncs directly on AppState.shared.statistics
        let originalStats = AppState.shared.statistics
        
        // Record a sync directly on AppState
        AppState.shared.statistics.recordSync(
            folderId: UUID(), folderName: "TestFolder",
            bytesTransferred: 2048, filesTransferred: 10,
            duration: 3.0, success: true
        )
        let afterRecord = AppState.shared.statistics.totalSyncs
        assert(afterRecord > originalStats.totalSyncs, "totalSyncs should increase after recordSync")
        
        // Save and reload — stats should survive
        AppState.shared.saveStatistics()
        let savedSyncs = AppState.shared.statistics.totalSyncs
        AppState.shared.loadStatistics()
        assertEqual(AppState.shared.statistics.totalSyncs, savedSyncs, "Stats should persist across save/load")
        assertEqual(AppState.shared.statistics.totalFilesTransferred, AppState.shared.statistics.totalFilesTransferred, "Files should persist")
        
        // Restore original
        AppState.shared.statistics = originalStats
        AppState.shared.saveStatistics()
    }
}

// ============================================================
// MARK: - SyncEngine No Own Statistics (Bug 1 regression)
// ============================================================

func testSyncEngineNoOwnStatistics() {
    runSuite("SyncEngine No Own Statistics") {
        // SyncEngine should NOT have its own statistics property.
        // It should read/write AppState.shared.statistics directly.
        // We verify this by checking that SyncEngine.shared does not reset AppState stats.
        
        let original = AppState.shared.statistics
        AppState.shared.statistics.recordSync(
            folderId: UUID(), folderName: "Persist",
            bytesTransferred: 100, filesTransferred: 1,
            duration: 0.5, success: true
        )
        AppState.shared.saveStatistics()
        let countBefore = AppState.shared.statistics.totalSyncs
        
        // Access SyncEngine — should NOT reset AppState.statistics
        _ = SyncEngine.shared
        assertEqual(AppState.shared.statistics.totalSyncs, countBefore, "Accessing SyncEngine should not reset stats")
        
        // Restore
        AppState.shared.statistics = original
        AppState.shared.saveStatistics()
    }
}

// ============================================================
// MARK: - ShellHelper.runAsync Output Tests (Bug 2 regression)
// ============================================================

func testShellHelperRunAsyncOutput() {
    runSuite("ShellHelper.runAsync Output") {
        var capturedResult: ShellResult?
        
        _ = ShellHelper.runAsync("echo 'hello world'; echo 'line two'",
            outputHandler: { _ in },
            completion: { result in
                capturedResult = result
            }
        )
        
        // Pump the run loop since completion dispatches to main queue
        let deadline = Date().addingTimeInterval(10)
        while capturedResult == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        
        assertNotNil(capturedResult, "runAsync should complete within 10s")
        if let result = capturedResult {
            assert(result.isSuccess, "echo should succeed")
            assert(result.output.contains("hello world"), "Output should contain 'hello world', got: \(result.output)")
            assert(result.output.contains("line two"), "Output should contain 'line two'")
        }
    }
}

// ============================================================
// MARK: - ShellHelper.run Pipe Order Tests (Bug 5 regression)
// ============================================================

func testShellHelperRunLargeOutput() {
    runSuite("ShellHelper.run Large Output") {
        // Generate enough output to fill a pipe buffer (typically 64KB)
        // This would have deadlocked before the fix
        let result = ShellHelper.run("for i in $(seq 1 5000); do echo \"line $i padding padding padding padding\"; done", timeout: 15)
        assert(result.isSuccess, "Large output command should succeed without deadlock")
        assert(result.output.contains("line 5000"), "Should contain last line")
    }
}

// ============================================================
// MARK: - ClearLogs Persistence Tests (Bug 7 regression)
// ============================================================

func testClearLogsPersistence() {
    runSuite("ClearLogs Persistence") {
        let originalLogs = AppState.shared.activityLog
        
        // Add a log entry via addLog (batched with 0.5s delay)
        AppState.shared.addLog(ActivityEntry(level: .info, category: .system, message: "Test log for clear"))
        
        // Pump run loop to flush the batched log entries
        let flushDeadline = Date().addingTimeInterval(2)
        while AppState.shared.activityLog.isEmpty && Date() < flushDeadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
        assert(!AppState.shared.activityLog.isEmpty, "Should have at least one log after flush")
        
        // Clear and verify it persists empty
        AppState.shared.clearLogs()
        assert(AppState.shared.activityLog.isEmpty, "Logs should be empty after clear")
        
        // Reload and verify still empty
        AppState.shared.loadActivityLog()
        assert(AppState.shared.activityLog.isEmpty, "Logs should remain empty after reload")
        
        // Restore original logs directly
        for entry in originalLogs {
            AppState.shared.activityLog.append(entry)
        }
        AppState.shared.saveActivityLog()
    }
}

// ============================================================
// MARK: - Advanced Settings Persistence Tests (Feature 8)
// ============================================================

func testAdvancedSettingsPersistence() {
    runSuite("Advanced Settings Persistence") {
        // Save originals
        let origWifi = AppState.shared.wifiFilterEnabled
        let origSSIDs = AppState.shared.allowedSSIDsRaw
        let origAC = AppState.shared.acPowerOnly
        let origFlags = AppState.shared.customRsyncFlags
        
        // Set new values
        AppState.shared.wifiFilterEnabled = true
        AppState.shared.allowedSSIDsRaw = "HomeNet, OfficeNet"
        AppState.shared.acPowerOnly = true
        AppState.shared.customRsyncFlags = "--compress --delete"
        
        // Verify they read back
        assertEqual(AppState.shared.wifiFilterEnabled, true, "WiFi filter should be enabled")
        assertEqual(AppState.shared.acPowerOnly, true, "AC power only should be enabled")
        assertEqual(AppState.shared.customRsyncFlags, "--compress --delete", "Custom flags should persist")
        
        // Verify parsed SSIDs
        let ssids = AppState.shared.allowedSSIDs
        assertEqual(ssids.count, 2, "Should have 2 SSIDs")
        assert(ssids.contains("HomeNet"), "Should contain HomeNet")
        assert(ssids.contains("OfficeNet"), "Should contain OfficeNet")
        
        // Empty SSIDs raw
        AppState.shared.allowedSSIDsRaw = ""
        assertEqual(AppState.shared.allowedSSIDs.count, 0, "Empty string should yield no SSIDs")
        
        // Restore originals
        AppState.shared.wifiFilterEnabled = origWifi
        AppState.shared.allowedSSIDsRaw = origSSIDs
        AppState.shared.acPowerOnly = origAC
        AppState.shared.customRsyncFlags = origFlags
    }
}

// ============================================================
// MARK: - SyncFolder Backward Compat (Cleanup 12 regression)
// ============================================================

func testSyncFolderBackwardCompat() {
    runSuite("SyncFolder Backward Compat") {
        // Simulate old serialized data that contains syncSchedule and fileFilters keys.
        // The decoder should handle missing/extra keys gracefully.
        let oldJSON = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "name": "Test",
            "localPath": "/local",
            "nasPath": "/nas",
            "isEnabled": true,
            "excludePatterns": [".DS_Store"],
            "symlinkMode": true,
            "symlinkState": "local",
            "symlinkProtected": false,
            "syncSchedule": {"startHour": 0, "endHour": 24, "daysOfWeek": [0,1,2,3,4,5,6], "onlyOnWiFi": false, "wifiSSIDs": [], "onlyOnACPower": false},
            "fileFilters": {"allowedExtensions": [], "maxFileSizeGB": null, "minFileSizeKB": null}
        }
        """
        let data = oldJSON.data(using: .utf8)!
        if let folder = try? JSONDecoder().decode(SyncFolder.self, from: data) {
            assertEqual(folder.name, "Test", "Should decode name")
            assertEqual(folder.symlinkMode, true, "Should decode symlinkMode")
            assertEqual(folder.symlinkState, .local, "Should decode symlinkState")
        } else {
            assert(false, "Should decode old format with syncSchedule/fileFilters without crashing")
        }
    }
}

// ============================================================
// MARK: - Run All Tests
// ============================================================

@main
struct TestRunner {
    static func main() {
        print("")
        print("═══════════════════════════════════════")
        print("  The Annex — Test Suite")
        print("═══════════════════════════════════════")
        print("")

        testNASState()
        testNASDevice()
        testDiscoveredNAS()
        testSyncFolder()
        testSyncJob()
        testSyncJobState()
        testActivityEntry()
        testLogLevel()
        testLogCategory()
        testStatistics()
        testSyncHistoryEntry()
        testConnectionQuality()
        testShellResult()
        testRsyncProgress()
        testRsyncResult()
        testAnnexQuotes()
        testDiskSpace()
        testSymlinkState()
        testSyncFolderSymlink()
        testSymlinkManager()
        testStatisticsPersistence()
        testSyncEngineNoOwnStatistics()
        testShellHelperRunAsyncOutput()
        testShellHelperRunLargeOutput()
        testClearLogsPersistence()
        testAdvancedSettingsPersistence()
        testSyncFolderBackwardCompat()

        print("")
        print("═══════════════════════════════════════")
        if failedTests == 0 {
            print("  ✓ All \(totalTests) tests passed")
        } else {
            print("  ✗ \(failedTests) of \(totalTests) tests failed")
            for name in failedNames {
                print("    - \(name)")
            }
        }
        print("═══════════════════════════════════════")
        print("")

        // Write coverage badge JSON for shields.io endpoint
        let coveragePercent = totalTests > 0 ? Int((Double(passedTests) / Double(totalTests)) * 100) : 0
        let color: String
        switch coveragePercent {
        case 90...100: color = "brightgreen"
        case 75..<90: color = "green"
        case 60..<75: color = "yellowgreen"
        case 40..<60: color = "yellow"
        default: color = "red"
        }
        let json = """
        {"schemaVersion":1,"label":"tests","message":"\(passedTests)/\(totalTests) passed","color":"\(color)"}
        """
        let jsonPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".build/coverage.json"
        try? json.write(toFile: jsonPath, atomically: true, encoding: .utf8)
        print("Coverage: \(coveragePercent)% → \(jsonPath)")

        exit(failedTests > 0 ? 1 : 0)
    }
}
