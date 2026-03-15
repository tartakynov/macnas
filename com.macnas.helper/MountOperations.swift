import Foundation

struct MountResult {
    var success: Bool
    var error: String?
}

/// Handles mount_nfs and umount operations.
final class MountOperations {

    /// Standard NFS mount options per plan.
    private let mountOptions = "vers=3,tcp,hard,intr,resvport,retrans=5,timeo=30,rsize=32768,wsize=32768,readahead=16,locallocks,nobrowse,nodev,nosuid"

    /// Mount an NFS share.
    func mount(serverIP: String, exportPath: String, mountPoint: String) -> MountResult {
        ensureDirectory(mountPoint)

        let source = "\(serverIP):\(exportPath)"
        let result = ProcessRunner.run("/sbin/mount_nfs", args: ["-o", mountOptions, source, mountPoint])

        if result.exitCode == 0 {
            return MountResult(success: true, error: nil)
        } else {
            let msg = result.stderr.isEmpty ? result.stdout : result.stderr
            return MountResult(success: false, error: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Unmount a mount point. Tries unmount(2) syscall first, falls back to diskutil.
    func unmount(mountPoint: String, force: Bool) -> MountResult {
        // Try direct syscall first
        let flags: Int32 = force ? MNT_FORCE : 0
        if Darwin.unmount(mountPoint, flags) == 0 {
            return MountResult(success: true, error: nil)
        }
        let unmountErrno = errno

        // Fallback: try diskutil
        let args = force ? ["unmount", "force", mountPoint] : ["unmount", mountPoint]
        let result = ProcessRunner.run("/usr/sbin/diskutil", args: args)
        if result.exitCode == 0 {
            return MountResult(success: true, error: nil)
        }

        let err = String(cString: strerror(unmountErrno))
        return MountResult(success: false, error: "unmount: \(err)")
    }

    /// Check if a mount point is currently mounted (appears in mount table).
    func isMounted(mountPoint: String) -> Bool {
        let result = ProcessRunner.run("/sbin/mount", args: [])
        return result.stdout.contains(" on \(mountPoint) ")
    }

    /// Ensure a directory exists, creating it if necessary.
    func ensureDirectory(_ path: String) {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) || !isDir.boolValue {
            try? FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

}
