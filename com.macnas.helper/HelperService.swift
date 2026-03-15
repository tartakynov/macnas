import Foundation
import os.log
import Shared
import SystemConfiguration

private let logger = Logger(subsystem: "com.macnas.helper", category: "mount")

/// Implements the XPC protocol. All methods run as root in the LaunchDaemon.
final class HelperService: NSObject, HelperProtocol {
    private let mountOps = MountOperations()
    private let healthChecker = HealthChecker()
    private let spotlightBlocker = SpotlightBlocker()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func mount(configData: Data, reply: @escaping (Bool, String?) -> Void) {
        guard let def = try? decoder.decode(MountDefinition.self, from: configData) else {
            logger.error("Failed to decode mount definition")
            reply(false, "Invalid mount definition")
            return
        }
        guard let config = loadConfig() else {
            logger.error("Failed to load config")
            reply(false, "Cannot load config")
            return
        }

        let mountPoint = def.mountPoint(root: config.mountRoot)
        logger.notice("Mounting \(config.serverIP, privacy: .public):\(def.exportPath, privacy: .public) -> \(mountPoint, privacy: .public)")
        let result = mountAndBlock(serverIP: config.serverIP, def: def, mountPoint: mountPoint)
        logger.notice("Mount result: success=\(result.success, privacy: .public) error=\(result.error ?? "none", privacy: .public)")
        reply(result.success, result.error)
    }

    func unmount(mountPoint: String, force: Bool, reply: @escaping (Bool, String?) -> Void) {
        logger.notice("Unmounting \(mountPoint, privacy: .public) force=\(force, privacy: .public)")
        let result = mountOps.unmount(mountPoint: mountPoint, force: force)
        logger.notice("Unmount result: success=\(result.success, privacy: .public) error=\(result.error ?? "none", privacy: .public)")
        reply(result.success, result.error)
    }

    func checkHealth(mountsData: Data, reply: @escaping (Data) -> Void) {
        guard let config = loadConfig(),
              let mounts = try? decoder.decode([MountDefinition].self, from: mountsData) else {
            reply(Data())
            return
        }

        let reports: [MountHealthReport] = {
            let lock = NSLock()
            var results = [MountHealthReport?](repeating: nil, count: mounts.count)
            let group = DispatchGroup()

            for (i, def) in mounts.enumerated() {
                group.enter()
                DispatchQueue.global().async {
                    let report = self.healthChecker.check(
                        mountPoint: def.mountPoint(root: config.mountRoot),
                        mountName: def.mountName,
                        serverIP: config.serverIP
                    )
                    lock.lock()
                    results[i] = report
                    lock.unlock()
                    group.leave()
                }
            }

            group.wait()
            return results.compactMap { $0 }
        }()

        let data = (try? encoder.encode(reports)) ?? Data()
        reply(data)
    }

    func pingServer(ip: String, reply: @escaping (Bool) -> Void) {
        let reachable = healthChecker.pingNFS(ip: ip)
        reply(reachable)
    }

    func applyConfig(mountsData: Data, reply: @escaping (Bool, String?) -> Void) {
        guard let config = loadConfig(),
              let mounts = try? decoder.decode([MountDefinition].self, from: mountsData) else {
            reply(false, "Invalid configuration data")
            return
        }

        // Create mount root if needed
        mountOps.ensureDirectory(config.mountRoot)

        var errors: [String] = []
        for def in mounts {
            let mountPoint = def.mountPoint(root: config.mountRoot)
            if mountOps.isMounted(mountPoint: mountPoint) { continue }

            let result = mountAndBlock(serverIP: config.serverIP, def: def, mountPoint: mountPoint)
            if !result.success {
                errors.append("\(def.mountName): \(result.error ?? "unknown error")")
            }
        }

        if errors.isEmpty {
            reply(true, nil)
        } else {
            reply(false, errors.joined(separator: "; "))
        }
    }

    func forceRecovery(mountsData: Data, reply: @escaping (Data) -> Void) {
        guard let config = loadConfig(),
              let mounts = try? decoder.decode([MountDefinition].self, from: mountsData) else {
            reply(Data())
            return
        }

        var reports: [MountHealthReport] = []
        for def in mounts {
            let mp = def.mountPoint(root: config.mountRoot)
            let health = healthChecker.check(mountPoint: mp, mountName: def.mountName, serverIP: config.serverIP)

            if health.status == .mounted {
                reports.append(health)
                continue
            }

            // Unhealthy — force unmount if present, then remount
            if mountOps.isMounted(mountPoint: mp) {
                _ = mountOps.unmount(mountPoint: mp, force: true)
                Thread.sleep(forTimeInterval: 0.5)
            }

            let result = mountAndBlock(serverIP: config.serverIP, def: def, mountPoint: mp)
            if result.success {
                reports.append(.mounted(name: def.mountName, point: mp))
            } else {
                reports.append(.error(name: def.mountName, point: mp, message: result.error))
            }
        }

        let data = (try? encoder.encode(reports)) ?? Data()
        reply(data)
    }

    // MARK: - Private

    /// Mount a share and block Spotlight if successful.
    private func mountAndBlock(serverIP: String, def: MountDefinition, mountPoint: String) -> MountResult {
        let result = mountOps.mount(serverIP: serverIP, exportPath: def.exportPath, mountPoint: mountPoint)
        if result.success {
            spotlightBlocker.block(mountPoint: mountPoint)
        }
        return result
    }

    private func loadConfig() -> MacNASConfig? {
        // When running as root, ~/Library points to /var/root/Library.
        // Find the console user's home instead.
        var uid: uid_t = 0
        guard let userName = SCDynamicStoreCopyConsoleUser(nil, &uid, nil) as String?,
              !userName.isEmpty,
              let pw = getpwuid(uid) else {
            return nil
        }
        let homeDir = String(cString: pw.pointee.pw_dir)
        let path = "\(homeDir)/Library/Application Support/MacNAS/config.json"
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        return try? decoder.decode(MacNASConfig.self, from: data)
    }
}
