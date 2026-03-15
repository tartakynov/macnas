import Foundation
import Shared

/// LaunchDaemon entry point. Sets up the XPC listener and runs the run loop.
final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = HelperService()

        connection.invalidationHandler = {
            // Connection closed — nothing to clean up
        }

        connection.resume()
        return true
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: kHelperMachServiceName)
listener.delegate = delegate
listener.resume()

RunLoop.current.run()
