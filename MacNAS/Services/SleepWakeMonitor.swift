import Foundation
import AppKit

/// Monitors system sleep/wake events.
@MainActor
final class SleepWakeMonitor {
    /// Callback after system wakes from sleep.
    var onWake: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Wait for network to stabilize after wake
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.onWake?()
            }
        }
        observers.append(wakeObserver)
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }
}
