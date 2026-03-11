import SwiftUI
import Charts

struct StatisticsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var syncEngine = SyncEngine.shared
    
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
                    GroupBox(label: Label("Sync History (Last 30 Days)", systemImage: "chart.line.uptrend.xyaxis")) {
                        if #available(macOS 13.0, *) {
                            SyncHistoryChart(history: recentHistory)
                                .frame(height: 200)
                                .padding()
                        } else {
                            Text("Charts require macOS 13+")
                                .foregroundColor(.secondary)
                                .frame(height: 200)
                        }
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
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return appState.statistics.syncHistory.filter { $0.date >= thirtyDaysAgo }
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

@available(macOS 13.0, *)
struct SyncHistoryChart: View {
    let history: [SyncHistoryEntry]
    
    var body: some View {
        Chart {
            ForEach(history) { entry in
                BarMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Bytes", Double(entry.bytesTransferred) / 1_000_000)
                )
                .foregroundStyle(entry.success ? Color.blue : Color.red)
            }
        }
        .chartYAxisLabel("MB Transferred")
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 5))
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
