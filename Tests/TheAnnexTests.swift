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
        assertNil(folder.syncSchedule)
        assertNil(folder.fileFilters)

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
// MARK: - SyncSchedule Tests
// ============================================================

func testSyncSchedule() {
    runSuite("SyncSchedule") {
        let schedule = SyncSchedule()
        assertEqual(schedule.startHour, 0)
        assertEqual(schedule.endHour, 24)
        assertEqual(schedule.daysOfWeek, [0, 1, 2, 3, 4, 5, 6])
        assert(!schedule.onlyOnWiFi, "Should not require WiFi by default")
        assertEqual(schedule.wifiSSIDs, [])
        assert(!schedule.onlyOnACPower, "Should not require AC by default")

        // Codable
        let custom = SyncSchedule(startHour: 9, endHour: 17, daysOfWeek: [1, 2, 3, 4, 5], onlyOnWiFi: true, wifiSSIDs: ["HomeNet"], onlyOnACPower: true)
        let data = try! JSONEncoder().encode(custom)
        let decoded = try! JSONDecoder().decode(SyncSchedule.self, from: data)
        assertEqual(decoded, custom)
    }
}

// ============================================================
// MARK: - FileFilters Tests
// ============================================================

func testFileFilters() {
    runSuite("FileFilters") {
        let filters = FileFilters()
        assertEqual(filters.allowedExtensions, [])
        assertNil(filters.maxFileSizeGB)
        assertNil(filters.minFileSizeKB)

        let custom = FileFilters(allowedExtensions: [".jpg", ".png"], maxFileSizeGB: 2.0, minFileSizeKB: 10.0)
        let data = try! JSONEncoder().encode(custom)
        let decoded = try! JSONDecoder().decode(FileFilters.self, from: data)
        assertEqual(decoded, custom)
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
        assertEqual(SyncJobState.paused.rawValue, "paused")
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
        testSyncSchedule()
        testFileFilters()
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

        exit(failedTests > 0 ? 1 : 0)
    }
}
