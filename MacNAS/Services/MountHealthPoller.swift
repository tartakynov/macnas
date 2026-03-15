import Foundation
import Shared

/// Coordinates periodic health checks and recovery actions.
@MainActor
final class MountHealthPoller {
    private let helperClient: HelperClient
    private let appState: AppState
    private var pollTask: Task<Void, Never>?
    private var checking = false

    init(helperClient: HelperClient, appState: AppState) {
        self.helperClient = helperClient
        self.appState = appState
    }

    /// Start the polling loop.
    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.performHealthCheck()

                let interval = self.appState.config.pollInterval

                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Stop the polling loop.
    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Trigger an immediate health check (e.g., after wake or link-up).
    func checkNow() {
        Task {
            await performHealthCheck()
        }
    }

    // MARK: - Private

    /// Force-unmount (if requested) then remount a single mount, updating status.
    private func recoverMount(_ mount: MountDefinition, forceUnmount: Bool) async {
        let mp = mount.mountPoint(root: appState.config.mountRoot)

        if forceUnmount {
            let (unmountOk, unmountErr) = await helperClient.unmount(mountPoint: mp, force: true)
            if !unmountOk {
                print("[MacNAS] unmount failed for \(mp): \(unmountErr ?? "unknown")")
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

        let (success, mountErr) = await helperClient.mount(mount)
        if success {
            appState.mountStatuses[mount.id] = .mounted
        } else {
            let msg = mountErr ?? "unknown error"
            print("[MacNAS] mount failed for \(mp): \(msg)")
            appState.mountStatuses[mount.id] = .error(msg)
        }
    }

    private func performHealthCheck() async {
        guard appState.config.isConfigured, !checking else { return }
        checking = true
        defer { checking = false }

        // Check network first
        if !appState.hasNetwork {
            appState.markAllNoNetwork()
            return
        }

        // Get health reports
        let reports = await helperClient.checkHealth(mounts: appState.config.mounts)
        appState.updateFromHealthReports(reports)

        // Auto-recover problematic mounts
        for report in reports {
            switch report.status {
            case .missing:
                if let def = appState.config.mounts.first(where: { $0.mountName == report.mountName }) {
                    await recoverMount(def, forceUnmount: false)
                }

            case .stale:
                if let def = appState.config.mounts.first(where: { $0.mountName == report.mountName }) {
                    await recoverMount(def, forceUnmount: true)
                }

            case .mounted, .noNetwork, .error:
                break
            }
        }
    }
}
