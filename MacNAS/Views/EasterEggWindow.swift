import AppKit
import SwiftUI

/// Tracks rapid menu bar icon clicks and shows an animated GIF easter egg.
@MainActor
final class EasterEggTracker: ObservableObject {
    private var openTimestamps: [Date] = []
    private let requiredClicks = 3
    private let timeWindow: TimeInterval = 3.0

    func recordOpen() {
        let now = Date()
        openTimestamps.append(now)
        // Keep only recent timestamps
        openTimestamps = openTimestamps.filter { now.timeIntervalSince($0) < timeWindow }
        if openTimestamps.count >= requiredClicks {
            openTimestamps.removeAll()
            showEasterEgg()
        }
    }

    private var easterEggWindow: NSWindow?

    private func showEasterEgg() {
        WindowManager.shared.dismissPopover()

        if let w = easterEggWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            return
        }

        guard let gifURL = Bundle.module.url(forResource: "love", withExtension: "gif"),
              let gifData = try? Data(contentsOf: gifURL),
              let image = NSImage(data: gifData) else { return }

        let imageView = NSImageView(frame: .zero)
        imageView.image = image
        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 300, height: 300)),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\u{2764}\u{fe0f}"
        window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView!.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
        ])
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        easterEggWindow = window
    }
}
