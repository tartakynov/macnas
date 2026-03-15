import Foundation

/// XPC protocol for communication between the menu bar app and the LaunchDaemon.
@objc public protocol HelperProtocol {
    func mount(configData: Data, reply: @escaping (Bool, String?) -> Void)
    func unmount(mountPoint: String, force: Bool, reply: @escaping (Bool, String?) -> Void)
    func checkHealth(mountsData: Data, reply: @escaping (Data) -> Void)
    func pingServer(ip: String, reply: @escaping (Bool) -> Void)
    func applyConfig(mountsData: Data, reply: @escaping (Bool, String?) -> Void)
    func forceRecovery(mountsData: Data, reply: @escaping (Data) -> Void)
}

/// Mach service name for the XPC connection.
public let kHelperMachServiceName = "com.macnas.helper"
