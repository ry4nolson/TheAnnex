import Foundation

struct ActivityEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let details: String?
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         level: LogLevel,
         category: LogCategory,
         message: String,
         details: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.details = details
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

enum LogLevel: String, Codable, CaseIterable {
    case debug
    case info
    case warning
    case error
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var iconName: String {
        switch self {
        case .debug: return "ant.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

enum LogCategory: String, Codable, CaseIterable {
    case sync
    case mount
    case network
    case system
    case error
    
    var displayName: String {
        rawValue.capitalized
    }
}
