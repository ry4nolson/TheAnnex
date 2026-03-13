import SwiftUI
import Charts

enum ChartTimeRange: String, CaseIterable, Identifiable {
    case oneHour = "1h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case oneDay = "1d"
    case sevenDays = "7d"
    case thirtyDays = "30d"
    
    var id: String { rawValue }
    
    var label: String { rawValue }
    
    var hoursBack: Int {
        switch self {
        case .oneHour: return 1
        case .sixHours: return 6
        case .twelveHours: return 12
        case .oneDay: return 24
        case .sevenDays: return 24 * 7
        case .thirtyDays: return 24 * 30
        }
    }
}

enum ChartInterval: String, CaseIterable, Identifiable {
    case oneMin = "1m"
    case fiveMin = "5m"
    case fifteenMin = "15m"
    case thirtyMin = "30m"
    case sixtyMin = "60m"
    case oneDay = "1d"
    
    var id: String { rawValue }
    
    var label: String { rawValue }
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .oneMin, .fiveMin, .fifteenMin, .thirtyMin, .sixtyMin: return .minute
        case .oneDay: return .day
        }
    }
    
    var minutes: Int {
        switch self {
        case .oneMin: return 1
        case .fiveMin: return 5
        case .fifteenMin: return 15
        case .thirtyMin: return 30
        case .sixtyMin: return 60
        case .oneDay: return 1440
        }
    }
}

struct StatisticsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var syncEngine = SyncEngine.shared
    @State private var selectedRange: ChartTimeRange = .oneDay
    @State private var selectedInterval: ChartInterval = .fiveMin
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    StatCard(
                        title: "Total Syncs",
                        value: "\(appState.statistics.totalSyncs)",
                        icon: "arrow.triangle.2.circlepath",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Success Rate",
                        value: String(format: "%.1f%%", appState.statistics.successRate * 100),
                        icon: "checkmark.circle",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Total Data",
                        value: appState.statistics.formattedTotalBytes,
                        icon: "externaldrive",
                        color: .purple
                    )
                    
                    StatCard(
                        title: "Files Synced",
                        value: "\(appState.statistics.totalFilesTransferred)",
                        icon: "doc.on.doc",
                        color: .orange
                    )
                }
                .padding(.horizontal)
                
                if appState.statistics.totalSyncs > 0 && appState.statistics.successRate >= 1.0,
                   let quote = AnnexQuotes.shared.quote(AnnexQuotes.perfectSuccessRate) {
                    Text(quote)
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal)
                }
                
                if !appState.statistics.syncHistory.isEmpty {
                    GroupBox {
                        VStack(spacing: 8) {
                            HStack {
                                Label("Sync History", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.headline)
                                Spacer()
                                Picker("Range", selection: $selectedRange) {
                                    ForEach(ChartTimeRange.allCases) { range in
                                        Text(range.label).tag(range)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 280)
                                
                                Picker("Interval", selection: $selectedInterval) {
                                    ForEach(ChartInterval.allCases) { interval in
                                        Text(interval.label).tag(interval)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 280)
                            }
                            
                            if #available(macOS 13.0, *) {
                                SyncHistoryChart(history: recentHistory, interval: selectedInterval, range: selectedRange)
                                    .frame(height: 200)
                                    .padding(.top, 4)
                            } else {
                                Text("Charts require macOS 13+")
                                    .foregroundColor(.secondary)
                                    .frame(height: 200)
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    GroupBox(label: Label("Recent Syncs", systemImage: "clock")) {
                        VStack(spacing: 0) {
                            ForEach(appState.statistics.syncHistory.suffix(10).reversed()) { entry in
                                SyncHistoryRow(entry: entry)
                                if entry.id != appState.statistics.syncHistory.suffix(10).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var recentHistory: [SyncHistoryEntry] {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -selectedRange.hoursBack, to: Date()) ?? Date()
        return appState.statistics.syncHistory.filter { $0.date >= cutoff }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ChartBucket: Identifiable {
    let id = UUID()
    let date: Date
    let megabytes: Double
    let isSuccess: Bool
}

@available(macOS 13.0, *)
struct SyncHistoryChart: View {
    let history: [SyncHistoryEntry]
    let interval: ChartInterval
    let range: ChartTimeRange
    
    private var buckets: [ChartBucket] {
        let minutes = interval.minutes
        var successMap: [Date: Double] = [:]
        var failureMap: [Date: Double] = [:]
        
        for entry in history {
            let bucketDate: Date
            if interval == .oneDay {
                bucketDate = Calendar.current.startOfDay(for: entry.date)
            } else {
                let ref = Calendar.current.startOfDay(for: entry.date)
                let elapsed = entry.date.timeIntervalSince(ref)
                let bucketIndex = Int(elapsed) / (minutes * 60)
                bucketDate = ref.addingTimeInterval(Double(bucketIndex * minutes * 60))
            }
            
            let mb = Double(entry.bytesTransferred) / 1_000_000
            if entry.success {
                successMap[bucketDate, default: 0] += mb
            } else {
                failureMap[bucketDate, default: 0] += mb
            }
        }
        
        var result: [ChartBucket] = []
        for (date, mb) in successMap {
            result.append(ChartBucket(date: date, megabytes: mb, isSuccess: true))
        }
        for (date, mb) in failureMap {
            result.append(ChartBucket(date: date, megabytes: mb, isSuccess: false))
        }
        return result.sorted { $0.date < $1.date }
    }
    
    private var axisStride: Calendar.Component {
        switch range {
        case .oneHour, .sixHours, .twelveHours, .oneDay:
            return .hour
        case .sevenDays, .thirtyDays:
            return .day
        }
    }
    
    private var axisStrideCount: Int {
        switch range {
        case .oneHour: return 1
        case .sixHours: return 1
        case .twelveHours: return 2
        case .oneDay: return 3
        case .sevenDays: return 1
        case .thirtyDays: return 5
        }
    }
    
    private var barWidth: MarkDimension {
        switch interval {
        case .oneMin: return .automatic
        case .fiveMin: return .fixed(4)
        case .fifteenMin: return .fixed(8)
        case .thirtyMin: return .fixed(14)
        case .sixtyMin: return .fixed(22)
        case .oneDay: return .fixed(30)
        }
    }
    
    var body: some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Time", bucket.date),
                    y: .value("MB", bucket.megabytes),
                    width: barWidth
                )
                .foregroundStyle(bucket.isSuccess ? Color.blue : Color.red)
            }
        }
        .chartYAxisLabel("MB Transferred")
        .chartXAxis {
            AxisMarks(values: .stride(by: axisStride, count: axisStrideCount)) { value in
                AxisGridLine()
                if axisStride == .hour {
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                } else {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
    }
}

struct SyncHistoryRow: View {
    let entry: SyncHistoryEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.folderName)
                    .font(.headline)
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(entry.success ? .green : .red)
                    Text(entry.formattedBytes)
                        .font(.subheadline)
                }
                Text("\(entry.filesTransferred) files • \(entry.formattedDuration) • \(entry.formattedSpeed)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
