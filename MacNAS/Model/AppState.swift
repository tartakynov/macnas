import Foundation
import Combine
import Shared

/// Central state container for the menu bar app.
@MainActor
final class AppState: ObservableObject {
    @Published var config: MacNASConfig
    @Published var mountStatuses: [UUID: MountStatus] = [:]
    @Published var hasNetwork: Bool = true

    init() {
        self.config = MacNASConfig.load()
    }

    /// Save config to disk.
    func saveConfig() {
        do {
            try config.save()
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    /// Update mount statuses from health reports.
    func updateFromHealthReports(_ reports: [MountHealthReport]) {
        for report in reports {
            if let mount = config.mounts.first(where: { $0.mountName == report.mountName }) {
                mountStatuses[mount.id] = MountStatus(from: report.status, message: report.message)
            }
        }
    }

    /// Mark all mounts with no-network status.
    func markAllNoNetwork() {
        for mount in config.mounts {
            mountStatuses[mount.id] = .noNetwork
        }
    }

    /// Status for a specific mount.
    func status(for mount: MountDefinition) -> MountStatus {
        mountStatuses[mount.id] ?? .unknown
    }

    enum OverallStatus {
        case good, warning, bad, unconfigured
    }

    var overallStatus: OverallStatus {
        if !hasNetwork { return .bad }
        if config.mounts.isEmpty { return .unconfigured }

        let statuses = config.mounts.map { status(for: $0) }

        if statuses.allSatisfy({ $0 == .mounted }) { return .good }
        if statuses.contains(where: { $0.isFailed }) { return .bad }
        return .warning
    }

    var menuBarIcon: String {
        switch overallStatus {
        case .good: return "externaldrive.fill.badge.checkmark"
        case .bad: return "exclamationmark.triangle.fill"
        case .warning: return "externaldrive.fill.badge.exclamationmark"
        case .unconfigured: return "externaldrive.fill"
        }
    }
}
