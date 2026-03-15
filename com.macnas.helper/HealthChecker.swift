import Foundation
import os.log
import Shared

private let logger = Logger(subsystem: "com.macnas.helper", category: "health")

/// Checks mount health: server reachability, mount presence, staleness.
final class HealthChecker {

    /// Ping server via ICMP.
    func pingNFS(ip: String) -> Bool {
        let result = ProcessRunner.run(
            "/sbin/ping",
            args: ["-c", "1", "-W", "3", ip],
            timeout: 5
        )
        return result.exitCode == 0
    }

    /// Full health check for a single mount point.
    func check(mountPoint: String, mountName: String, serverIP: String) -> MountHealthReport {
        // 1. Is it in the mount table?
        let mounted = isMounted(mountPoint)

        if !mounted {
            logger.warning("\(mountName, privacy: .public): not in mount table (mountPoint=\(mountPoint, privacy: .public))")
            return .missing(name: mountName, point: mountPoint)
        }

        // 2. Try statfs with timeout to detect stale/unresponsive
        let statResult = checkStat(mountPoint)

        switch statResult {
        case .ok:
            return .mounted(name: mountName, point: mountPoint)
        case .stale:
            logger.error("\(mountName, privacy: .public): stat reports stale NFS handle (mountPoint=\(mountPoint, privacy: .public))")
            return .stale(name: mountName, point: mountPoint)
        case .timeout:
            logger.error("\(mountName, privacy: .public): stat timed out — reporting unreachable (mountPoint=\(mountPoint, privacy: .public))")
            return .unreachable(name: mountName, point: mountPoint)
        case .error(let msg):
            logger.error("\(mountName, privacy: .public): stat failed — \(msg, privacy: .public) (mountPoint=\(mountPoint, privacy: .public))")
            return .error(name: mountName, point: mountPoint, message: msg)
        }
    }

    // MARK: - Private

    private enum StatResult {
        case ok
        case stale
        case timeout
        case error(String)
    }

    private func isMounted(_ mountPoint: String) -> Bool {
        MountOperations().isMounted(mountPoint: mountPoint)
    }

    /// Check if a mount is accessible by running stat on it with a timeout.
    /// We use a subprocess because statfs() can hang indefinitely on unresponsive NFS mounts.
    private func checkStat(_ mountPoint: String) -> StatResult {
        let result = ProcessRunner.run("/usr/bin/stat", args: ["-f", "%d", mountPoint], timeout: 5)

        if result.timedOut {
            return .timeout
        }

        if result.exitCode == 0 {
            return .ok
        }

        let errMsg = result.stderr.lowercased()
        if errMsg.contains("stale") {
            return .stale
        }

        return .error(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
