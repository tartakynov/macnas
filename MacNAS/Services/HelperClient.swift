import Foundation
import Shared

/// XPC client for communicating with the LaunchDaemon.
final class HelperClient {
    private var connection: NSXPCConnection?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Get or create the XPC connection.
    private func getProxy() -> HelperProtocol? {
        if connection == nil {
            let conn = NSXPCConnection(machServiceName: kHelperMachServiceName, options: .privileged)
            conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
            conn.invalidationHandler = { [weak self] in
                self?.connection = nil
            }
            conn.resume()
            connection = conn
        }

        return connection?.remoteObjectProxyWithErrorHandler { error in
            print("XPC error: \(error)")
        } as? HelperProtocol
    }

    /// Mount a single share.
    func mount(_ definition: MountDefinition) async -> (Bool, String?) {
        guard let proxy = getProxy(),
              let data = try? encoder.encode(definition) else {
            return (false, "Cannot connect to helper")
        }

        return await withCheckedContinuation { continuation in
            proxy.mount(configData: data) { success, error in
                continuation.resume(returning: (success, error))
            }
        }
    }

    /// Unmount a mount point.
    func unmount(mountPoint: String, force: Bool = false) async -> (Bool, String?) {
        guard let proxy = getProxy() else {
            return (false, "Cannot connect to helper")
        }

        return await withCheckedContinuation { continuation in
            proxy.unmount(mountPoint: mountPoint, force: force) { success, error in
                continuation.resume(returning: (success, error))
            }
        }
    }

    /// Check health of all mounts.
    func checkHealth(mounts: [MountDefinition]) async -> [MountHealthReport] {
        guard let proxy = getProxy(),
              let data = try? encoder.encode(mounts) else {
            return []
        }

        return await withCheckedContinuation { continuation in
            proxy.checkHealth(mountsData: data) { reportData in
                let reports = (try? self.decoder.decode([MountHealthReport].self, from: reportData)) ?? []
                continuation.resume(returning: reports)
            }
        }
    }

    /// Apply full configuration — mount everything that isn't mounted.
    func applyConfig(mounts: [MountDefinition]) async -> (Bool, String?) {
        guard let proxy = getProxy(),
              let data = try? encoder.encode(mounts) else {
            return (false, "Cannot connect to helper")
        }

        return await withCheckedContinuation { continuation in
            proxy.applyConfig(mountsData: data) { success, error in
                continuation.resume(returning: (success, error))
            }
        }
    }
}
