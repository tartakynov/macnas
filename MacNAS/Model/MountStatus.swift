import SwiftUI
import Shared

/// UI-facing mount status, derived from MountHealthReport.
enum MountStatus: Equatable {
    case unknown
    case mounted
    case stale
    case missing
    case noNetwork
    case error(String)

    var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .mounted: return "Mounted"
        case .stale: return "Stale"
        case .missing: return "Not Mounted"
        case .noNetwork: return "No Network"
        case .error: return "Error"
        }
    }

    var color: Color {
        switch self {
        case .mounted: return .green
        case .unknown: return .gray
        case .missing: return .yellow
        case .stale, .noNetwork, .error: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .mounted: return "externaldrive.fill.badge.checkmark"
        case .unknown: return "externaldrive.fill.badge.questionmark"
        case .missing: return "externaldrive.badge.minus"
        case .stale, .error: return "externaldrive.fill.badge.xmark"
        case .noNetwork: return "externaldrive.fill.badge.wifi.slash"
        }
    }

    var isFailed: Bool {
        switch self {
        case .stale, .noNetwork, .error: return true
        default: return false
        }
    }

    init(from health: MountHealthStatus, message: String? = nil) {
        switch health {
        case .mounted: self = .mounted
        case .stale: self = .stale
        case .missing: self = .missing
        case .noNetwork: self = .noNetwork
        case .error: self = .error(message ?? "unknown error")
        }
    }
}
