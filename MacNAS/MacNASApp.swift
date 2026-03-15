import SwiftUI
import Shared
import ServiceManagement

@main
struct MacNASApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var serviceManager = ServiceManager()
    @StateObject private var easterEgg = EasterEggTracker()

    init() {
        HelperInstaller.installIfNeeded()
        try? SMAppService.mainApp.register()
    }

    var body: some Scene {
        MenuBarExtra {
            MountListView(
                appState: appState,
                onRemount: { mount in serviceManager.healthPoller?.remount(mount) }
            )
            .task {
                if !serviceManager.started {
                    serviceManager.start(appState: appState)
                }
            }
            .onAppear {
                easterEgg.recordOpen()
            }
        } label: {
            Image(systemName: appState.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Manages the lifecycle of background services.
@MainActor
final class ServiceManager: ObservableObject {
    let helperClient = HelperClient()
    var healthPoller: MountHealthPoller?
    private let networkMonitor = NetworkMonitor()
    private let sleepWakeMonitor = SleepWakeMonitor()
    var started = false

    func start(appState: AppState) {
        guard !started else { return }
        started = true

        let poller = MountHealthPoller(helperClient: helperClient, appState: appState)
        self.healthPoller = poller

        // Network monitor — trigger health check on link-up
        networkMonitor.onLinkUp = { [weak poller] in
            poller?.checkNow()
        }
        networkMonitor.start()

        // Sync network state to app state
        Task { [weak self] in
            guard let self else { return }
            for await hasEth in self.networkMonitor.$hasNetwork.values {
                appState.hasNetwork = hasEth
            }
        }

        // Sleep/wake monitor — trigger health check on wake
        sleepWakeMonitor.onWake = { [weak poller] in
            poller?.checkNow()
        }
        sleepWakeMonitor.start()

        // Start polling
        poller.start()

        // Apply config on launch
        Task {
            if appState.config.isConfigured {
                _ = await helperClient.applyConfig(mounts: appState.config.mounts)
                poller.checkNow()
            }
        }
    }
}
