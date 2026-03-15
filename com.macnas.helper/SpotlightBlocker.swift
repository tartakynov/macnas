import Foundation

/// Prevents Spotlight from indexing NFS mount points.
final class SpotlightBlocker {

    /// Block Spotlight indexing on a mount point.
    /// Creates .metadata_never_index and runs mdutil -i off.
    func block(mountPoint: String) {
        createMetadataNeverIndex(mountPoint)
        disableMdutil(mountPoint)
    }

    // MARK: - Private

    private func createMetadataNeverIndex(_ mountPoint: String) {
        let flagFile = (mountPoint as NSString).appendingPathComponent(".metadata_never_index")
        if !FileManager.default.fileExists(atPath: flagFile) {
            FileManager.default.createFile(atPath: flagFile, contents: nil)
        }
    }

    private func disableMdutil(_ mountPoint: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdutil")
        process.arguments = ["-i", "off", mountPoint]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
