import SwiftUI

struct SyncFoldersView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var syncEngine = SyncEngine.shared
    @State private var showingAddFolder = false
    @State private var selectedFolder: SyncFolder?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Configured Sync Folders")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddFolder = true }) {
                    Label("Add Folder", systemImage: "plus")
                }
                Button(action: syncAllFolders) {
                    Label("Sync All", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(appState.syncFolders.filter { $0.isEnabled }.isEmpty)
            }
            .padding()
            
            Divider()
            
            if appState.syncFolders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No sync folders configured")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Add folders to sync between your Mac and NAS")
                        .foregroundColor(.secondary)
                    Button("Add Your First Folder") {
                        showingAddFolder = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.syncFolders) { folder in
                        SyncFolderRow(folder: folder, onEdit: {
                            selectedFolder = folder
                        }, onSync: {
                            syncEngine.queueSync(for: folder)
                        }, onDelete: {
                            deleteFolder(folder)
                        })
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active Syncs")
                        .font(.headline)
                    if !syncEngine.activeSyncJobs.isEmpty {
                        Text("(\(syncEngine.activeSyncJobs.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !syncEngine.activeSyncJobs.isEmpty {
                        Button("Cancel All") {
                            syncEngine.cancelAll()
                        }
                    }
                }
                .padding(.horizontal)
                
                if syncEngine.activeSyncJobs.isEmpty {
                    HStack {
                        Spacer()
                        Text("No active syncs")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(syncEngine.activeSyncJobs) { job in
                                ActiveSyncJobRow(job: job, onCancel: {
                                    syncEngine.cancelSync(jobId: job.id)
                                })
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(height: 220)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .sheet(isPresented: $showingAddFolder) {
            AddSyncFolderSheet(isPresented: $showingAddFolder)
        }
        .sheet(item: $selectedFolder) { folder in
            EditSyncFolderSheet(folder: folder, isPresented: Binding(
                get: { selectedFolder != nil },
                set: { if !$0 { selectedFolder = nil } }
            ))
        }
    }
    
    private func syncAllFolders() {
        syncEngine.queueSyncAll(folders: appState.syncFolders)
    }
    
    private func deleteFolder(_ folder: SyncFolder) {
        // Unsymlink if currently symlinked
        if folder.symlinkMode && folder.symlinkState == .symlinked {
            let _ = SymlinkManager.shared.removeSymlink(localPath: folder.localPath)
            SymlinkManager.shared.removeBackup(for: folder.localPath)
        }
        appState.removeSyncFolder(folder)
    }
}

struct SyncFolderRow: View {
    let folder: SyncFolder
    let onEdit: () -> Void
    let onSync: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folder.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(folder.isEnabled ? .green : .secondary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption)
                    Text(folder.localPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "externaldrive")
                        .font(.caption)
                    Text(folder.nasPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if folder.symlinkMode {
                    HStack(spacing: 4) {
                        Image(systemName: folder.symlinkState == .symlinked ? "link" : "link.badge.plus")
                            .font(.caption)
                        Text(folder.symlinkState == .symlinked ? "Symlinked to NAS" : folder.symlinkState == .restoring ? "Transitioning..." : "Symlink mode (local)")
                            .font(.caption2)
                        .foregroundColor(folder.symlinkState == .symlinked ? .blue : .orange)
                    }
                }
                if let lastSync = folder.lastSyncDate {
                    Text("Last synced: \(lastSync, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onSync) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .help("Sync Now")
            .disabled(!folder.isEnabled)
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .help("Edit")
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .help("Delete")
        }
        .padding(.vertical, 4)
    }
}

struct ActiveSyncJobRow: View {
    @ObservedObject var job: SyncJob
    let onCancel: () -> Void
    @State private var showRawLog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.folderName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: { showRawLog.toggle() }) {
                    Image(systemName: showRawLog ? "terminal.fill" : "terminal")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(showRawLog ? "Hide raw log" : "Show raw log")
                if job.state == .running {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel sync")
                }
                Text(job.state.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if job.state == .running {
                if job.totalFiles > 0 {
                    ProgressView(value: Double(job.filesTransferred), total: Double(job.totalFiles))
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                }
            }
            
            if let currentFile = job.currentFile, !currentFile.isEmpty {
                Text(currentFile)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if job.state == .running {
                Text("Scanning files…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if job.totalFiles > 0 {
                    let percentage = Int((Double(job.filesTransferred) / Double(job.totalFiles)) * 100)
                    Text("\(job.filesTransferred) / \(job.totalFiles) files (\(percentage)%)")
                        .font(.caption2)
                        .fontWeight(.medium)
                } else {
                    Text("\(job.filesTransferred) files")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                Text("•")
                    .font(.caption2)
                Text(ByteCountFormatter.string(fromByteCount: job.bytesTransferred, countStyle: .file))
                    .font(.caption2)
                    .fontWeight(.medium)
                if job.transferSpeed > 0 {
                    Text("•")
                        .font(.caption2)
                    Text("\(ByteCountFormatter.string(fromByteCount: Int64(job.transferSpeed), countStyle: .file))/s")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            .foregroundColor(.secondary)
            
            if showRawLog {
                RawLogView(job: job)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

struct RawLogView: View {
    let job: SyncJob
    @State private var displayedLines: [String] = []
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(displayedLines.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .id(idx)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .background(Color.black)
            .cornerRadius(4)
            .onReceive(timer) { _ in
                let latest = job.rawLog
                if latest.count != displayedLines.count {
                    displayedLines = latest
                    if let last = displayedLines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                displayedLines = job.rawLog
            }
        }
    }
}

struct AddSyncFolderSheet: View {
    @Binding var isPresented: Bool
    @State private var selectedPreset: SyncFolder?
    @State private var customName = ""
    @State private var customLocalPath = ""
    @State private var customNASPath = ""
    @State private var useCustom = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Sync Folder")
                .font(.title2)
                .fontWeight(.bold)
            
            Picker("Source", selection: $useCustom) {
                Text("Preset Folders").tag(false)
                Text("Custom Folder").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if useCustom {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Folder Name", text: $customName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Local Path", text: $customLocalPath)
                        .textFieldStyle(.roundedBorder)
                    TextField("NAS Path", text: $customNASPath)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(SyncFolder.presets) { preset in
                            Button(action: {
                                selectedPreset = preset
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.name)
                                            .font(.headline)
                                        Text(preset.localPath)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("→ \(preset.nasPath)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedPreset?.id == preset.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(8)
                                .background(selectedPreset?.id == preset.id ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            if preset.id != SyncFolder.presets.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    addFolder()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .padding()
    }
    
    private var canAdd: Bool {
        if useCustom {
            return !customName.isEmpty && !customLocalPath.isEmpty && !customNASPath.isEmpty
        } else {
            return selectedPreset != nil
        }
    }
    
    private func addFolder() {
        let folder: SyncFolder
        if useCustom {
            folder = SyncFolder(
                name: customName,
                localPath: customLocalPath,
                nasPath: customNASPath
            )
        } else if let preset = selectedPreset {
            folder = preset
        } else {
            return
        }
        
        AppState.shared.addSyncFolder(folder)
        isPresented = false
    }
}

struct EditSyncFolderSheet: View {
    let folder: SyncFolder
    @Binding var isPresented: Bool
    
    @State private var folderName: String
    @State private var localPath: String
    @State private var nasPath: String
    @State private var isEnabled: Bool
    @State private var excludePatterns: String
    @State private var symlinkMode: Bool
    
    init(folder: SyncFolder, isPresented: Binding<Bool>) {
        self.folder = folder
        self._isPresented = isPresented
        self._folderName = State(initialValue: folder.name)
        self._localPath = State(initialValue: folder.localPath)
        self._nasPath = State(initialValue: folder.nasPath)
        self._isEnabled = State(initialValue: folder.isEnabled)
        self._excludePatterns = State(initialValue: folder.excludePatterns.joined(separator: "\n"))
        self._symlinkMode = State(initialValue: folder.symlinkMode)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit: \(folder.name)")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle("Enabled", isOn: $isEnabled)
                    Spacer()
                }
                
                HStack {
                    Toggle("Symlink Mode", isOn: $symlinkMode)
                    Spacer()
                }
                
                if symlinkMode {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Symlink mode replaces your local folder with a link to the NAS. When the NAS goes offline, the link is removed so files save locally. When it comes back, new files sync to the NAS and the link is restored.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
                
                HStack {
                    Text("Name:")
                        .frame(width: 70, alignment: .trailing)
                    TextField("Folder Name", text: $folderName)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Local:")
                        .frame(width: 70, alignment: .trailing)
                    TextField("Local Path", text: $localPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") {
                        browseLocal()
                    }
                }
                
                HStack {
                    Text("NAS:")
                        .frame(width: 70, alignment: .trailing)
                    TextField("NAS Path", text: $nasPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse") {
                        browseNAS()
                    }
                }
                
                Text("Exclude Patterns (one per line):")
                    .font(.subheadline)
                TextEditor(text: $excludePatterns)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .border(Color.secondary.opacity(0.3))
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(folderName.isEmpty || localPath.isEmpty || nasPath.isEmpty)
            }
        }
        .frame(width: 500)
        .padding(20)
    }
    
    private func browseLocal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: localPath)
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }
    
    private func browseNAS() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        if panel.runModal() == .OK, let url = panel.url {
            nasPath = url.path
        }
    }
    
    private func saveChanges() {
        var updated = folder
        updated.name = folderName
        updated.localPath = localPath
        updated.nasPath = nasPath
        updated.isEnabled = isEnabled
        updated.excludePatterns = excludePatterns
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        updated.symlinkMode = symlinkMode
        
        AppState.shared.updateSyncFolder(updated)
        isPresented = false
    }
}
