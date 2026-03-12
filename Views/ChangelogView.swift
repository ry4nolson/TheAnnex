import SwiftUI

struct ChangelogView: View {
    let releases: [ChangelogRelease]
    @State private var expandedVersions: Set<String> = []
    
    init() {
        self.releases = ChangelogParser.parse()
        // Auto-expand the latest release
        if let first = releases.first {
            _expandedVersions = State(initialValue: [first.version])
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's New")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 12)
            
            if releases.isEmpty {
                Text("No changelog available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(releases) { release in
                            ChangelogReleaseRow(
                                release: release,
                                isExpanded: expandedVersions.contains(release.version),
                                onToggle: {
                                    if expandedVersions.contains(release.version) {
                                        expandedVersions.remove(release.version)
                                    } else {
                                        expandedVersions.insert(release.version)
                                    }
                                }
                            )
                            
                            if release.id != releases.last?.id {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ChangelogReleaseRow: View {
    let release: ChangelogRelease
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                    
                    Text(release.version)
                        .font(.headline)
                    
                    if let date = release.date {
                        Text(date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if release.version == "Unreleased" {
                        Text("dev")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(release.sections) { section in
                        ChangelogSectionView(section: section)
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChangelogSectionView: View {
    let section: ChangelogSection
    
    var sectionColor: Color {
        switch section.title.lowercased() {
        case "added": return .green
        case "fixed": return .blue
        case "changed": return .orange
        case "removed": return .red
        default: return .secondary
        }
    }
    
    var sectionIcon: String {
        switch section.title.lowercased() {
        case "added": return "plus.circle.fill"
        case "fixed": return "wrench.and.screwdriver.fill"
        case "changed": return "arrow.triangle.2.circlepath"
        case "removed": return "minus.circle.fill"
        default: return "circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: sectionIcon)
                    .font(.caption)
                    .foregroundColor(sectionColor)
                Text(section.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(sectionColor)
            }
            
            ForEach(section.items, id: \.self) { item in
                ChangelogItemView(item: item)
            }
        }
    }
}

struct ChangelogItemView: View {
    let item: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 1)
            
            formattedText(item)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 4)
    }
    
    private func formattedText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text
        
        while let boldStart = remaining.range(of: "**") {
            let before = String(remaining[remaining.startIndex..<boldStart.lowerBound])
            if !before.isEmpty {
                result = result + Text(before)
            }
            remaining = String(remaining[boldStart.upperBound...])
            
            if let boldEnd = remaining.range(of: "**") {
                let boldText = String(remaining[remaining.startIndex..<boldEnd.lowerBound])
                result = result + Text(boldText).fontWeight(.semibold)
                remaining = String(remaining[boldEnd.upperBound...])
            } else {
                result = result + Text("**" + remaining)
                remaining = ""
            }
        }
        
        if !remaining.isEmpty {
            result = result + Text(remaining)
        }
        
        return result
    }
}

// MARK: - Parser

struct ChangelogRelease: Identifiable {
    let id = UUID()
    let version: String
    let date: String?
    var sections: [ChangelogSection]
}

struct ChangelogSection: Identifiable {
    let id = UUID()
    let title: String
    var items: [String]
}

enum ChangelogParser {
    static func parse() -> [ChangelogRelease] {
        guard let path = Bundle.main.resourcePath else { return [] }
        let filePath = (path as NSString).appendingPathComponent("CHANGELOG.md")
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return [] }
        return parseContent(content)
    }
    
    static func parseContent(_ content: String) -> [ChangelogRelease] {
        let lines = content.components(separatedBy: .newlines)
        var releases: [ChangelogRelease] = []
        var currentRelease: ChangelogRelease?
        var currentSection: ChangelogSection?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Version header: ## [1.5.0] - 2026-03-12  or  ## [Unreleased]
            if trimmed.hasPrefix("## ") {
                // Save current section to current release
                if let section = currentSection {
                    currentRelease?.sections.append(section)
                    currentSection = nil
                }
                // Save current release
                if let release = currentRelease {
                    releases.append(release)
                }
                
                let header = String(trimmed.dropFirst(3))
                let (version, date) = parseVersionHeader(header)
                currentRelease = ChangelogRelease(version: version, date: date, sections: [])
            }
            // Section header: ### Added, ### Fixed, etc.
            else if trimmed.hasPrefix("### ") {
                if let section = currentSection {
                    currentRelease?.sections.append(section)
                }
                let title = String(trimmed.dropFirst(4))
                currentSection = ChangelogSection(title: title, items: [])
            }
            // List item: - **Bold** — description
            else if trimmed.hasPrefix("- ") {
                let item = String(trimmed.dropFirst(2))
                currentSection?.items.append(item)
            }
        }
        
        // Save remaining
        if let section = currentSection {
            currentRelease?.sections.append(section)
        }
        if let release = currentRelease {
            releases.append(release)
        }
        
        // Filter out empty releases (like Unreleased with no sections)
        return releases.filter { !$0.sections.isEmpty }
    }
    
    private static func parseVersionHeader(_ header: String) -> (String, String?) {
        // [Unreleased]
        if header.contains("Unreleased") {
            return ("Unreleased", nil)
        }
        
        // [1.5.0] - 2026-03-12
        var version = header
        var date: String?
        
        if let bracketStart = header.firstIndex(of: "["),
           let bracketEnd = header.firstIndex(of: "]") {
            version = String(header[header.index(after: bracketStart)..<bracketEnd])
        }
        
        if let dashRange = header.range(of: " - ") {
            date = String(header[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        
        return (version, date)
    }
}
