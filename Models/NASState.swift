import Foundation

enum NASState: String, Codable {
    case connected
    case offline
    case syncing
    case paused
    case error
    
    var displayName: String {
        switch self {
        case .connected: return "Connected"
        case .offline: return "Offline"
        case .syncing: return "Syncing"
        case .paused: return "Paused"
        case .error: return "Error"
        }
    }
    
    var iconName: String {
        switch self {
        case .connected: return "externaldrive.fill.badge.checkmark"
        case .offline: return "externaldrive.badge.xmark"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .paused: return "pause.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
