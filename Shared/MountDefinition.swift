import Foundation

/// A single NFS mount definition.
public struct MountDefinition: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var exportPath: String
    public var mountName: String

    public init(id: UUID, exportPath: String, mountName: String) {
        self.id = id
        self.exportPath = exportPath
        self.mountName = mountName
    }

    public func mountPoint(root: String) -> String {
        return (root as NSString).appendingPathComponent(mountName)
    }
}

/// Overall app configuration.
public struct MacNASConfig: Codable, Equatable {
    public var serverIP: String
    public var mountRoot: String
    public var pollInterval: TimeInterval
    public var mounts: [MountDefinition]

    public init(
        serverIP: String = "",
        mountRoot: String = "/Volumes/NAS",
        pollInterval: TimeInterval = 15,
        mounts: [MountDefinition] = []
    ) {
        self.serverIP = serverIP
        self.mountRoot = mountRoot
        self.pollInterval = pollInterval
        self.mounts = mounts
    }

    public static let defaultPath: String = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacNAS")
        return dir.appendingPathComponent("config.json").path
    }()

    public static func load() -> MacNASConfig {
        guard let data = FileManager.default.contents(atPath: defaultPath),
              let config = try? JSONDecoder().decode(MacNASConfig.self, from: data) else {
            return MacNASConfig()
        }
        return config
    }

    public func save() throws {
        let url = URL(fileURLWithPath: Self.defaultPath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }
}

/// Health report for a single mount.
public struct MountHealthReport: Codable {
    public var mountName: String
    public var mountPoint: String
    public var status: MountHealthStatus
    public var message: String?

    public init(mountName: String, mountPoint: String, status: MountHealthStatus, message: String? = nil) {
        self.mountName = mountName
        self.mountPoint = mountPoint
        self.status = status
        self.message = message
    }
}

extension MountHealthReport {
    public static func missing(name: String, point: String) -> MountHealthReport {
        MountHealthReport(mountName: name, mountPoint: point, status: .missing, message: "Not in mount table")
    }

    public static func mounted(name: String, point: String) -> MountHealthReport {
        MountHealthReport(mountName: name, mountPoint: point, status: .mounted)
    }

    public static func stale(name: String, point: String) -> MountHealthReport {
        MountHealthReport(mountName: name, mountPoint: point, status: .stale, message: "Stale NFS file handle")
    }

    public static func unreachable(name: String, point: String) -> MountHealthReport {
        MountHealthReport(mountName: name, mountPoint: point, status: .unreachable, message: "Mount unresponsive (timed out)")
    }

    public static func error(name: String, point: String, message: String?) -> MountHealthReport {
        MountHealthReport(mountName: name, mountPoint: point, status: .error, message: message)
    }
}

/// Status from health check.
public enum MountHealthStatus: String, Codable {
    case mounted
    case stale
    case unreachable
    case missing
    case noNetwork
    case error
}
