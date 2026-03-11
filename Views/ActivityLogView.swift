import SwiftUI
import UniformTypeIdentifiers

struct ActivityLogView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var searchText = ""
    @State private var selectedLevel: LogLevel?
    @State private var selectedCategory: LogCategory?
    @State private var showingExportSheet = false
    
    var filteredLogs: [ActivityEntry] {
        appState.activityLog.filter { entry in
            let matchesSearch = searchText.isEmpty || 
                entry.message.localizedCaseInsensitiveContains(searchText)
            let matchesLevel = selectedLevel == nil || entry.level == selectedLevel
            let matchesCategory = selectedCategory == nil || entry.category == selectedCategory
            return matchesSearch && matchesLevel && matchesCategory
        }.reversed()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                
                Picker("Level", selection: $selectedLevel) {
                    Text("All Levels").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level as LogLevel?)
                    }
                }
                .frame(width: 150)
                
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag(nil as LogCategory?)
                    ForEach(LogCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category as LogCategory?)
                    }
                }
                .frame(width: 150)
                
                Spacer()
                
                Button(action: { showingExportSheet = true }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button(action: clearLogs) {
                    Label("Clear", systemImage: "trash")
                }
            }
            .padding()
            
            Divider()
            
            if filteredLogs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No activity logs")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    if let quote = AnnexQuotes.shared.quote(AnnexQuotes.emptyActivityLog) {
                        Text(quote)
                            .font(.caption)
                            .italic()
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredLogs) { entry in
                    ActivityLogRow(entry: entry)
                }
            }
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: LogDocument(content: appState.exportLogs()),
            contentType: .plainText,
            defaultFilename: "TheAnnex-Logs-\(Date().ISO8601Format()).txt"
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
    
    private func clearLogs() {
        appState.clearLogs()
    }
}

struct ActivityLogRow: View {
    let entry: ActivityEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.level.iconName)
                .foregroundColor(levelColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(entry.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(entry.message)
                    .font(.body)
                
                if let details = entry.details {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    
    var content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        content = ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
