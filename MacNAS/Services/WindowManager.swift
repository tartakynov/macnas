import AppKit
import SwiftUI

/// Opens standalone NSWindows for settings,
/// avoiding the MenuBarExtra popover focus-loss issue.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var settingsWindow: NSWindow?

    /// Dismiss the MenuBarExtra popover by ordering out its panel.
    func dismissPopover() {
        for window in NSApp.windows {
            let name = type(of: window).description()
            if name.contains("StatusBarWindow") || name.contains("MenuBarExtraWindow") {
                window.orderOut(nil)
            }
        }
    }

    func openSettings(appState: AppState) {
        dismissPopover()
        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(appState: appState, onDismiss: { [weak self] in
            self?.settingsWindow?.close()
        })
        let window = makeWindow(title: "MacNAS Settings", view: view, size: NSSize(width: 450, height: 380))
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow<V: View>(title: String, view: V, size: NSSize) -> NSWindow {
        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        return window
    }
}
