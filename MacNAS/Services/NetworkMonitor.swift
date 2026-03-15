import Foundation
import Network

/// Monitors network availability using NWPathMonitor.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var hasNetwork: Bool = true

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.macnas.networkmonitor")

    /// Callback when network comes back up.
    var onLinkUp: (() -> Void)?

    func start() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasDown = !self.hasNetwork
                self.hasNetwork = satisfied

                if wasDown && satisfied {
                    // Network came back — trigger recovery after short delay
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        self.onLinkUp?()
                    }
                }
            }
        }
        monitor.start(queue: queue)
        self.monitor = monitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }
}
