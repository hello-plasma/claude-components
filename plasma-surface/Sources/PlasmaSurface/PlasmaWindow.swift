import AppKit
import SwiftUI

/// Manages the single Plasma content window.
@MainActor
final class PlasmaWindow {
    var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        if window == nil {
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let contentView = PlasmaSurfaceView(plasmaState: appState.plasmaState)

        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Plasma Surface"
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("PlasmaWindow")
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        window.backgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)

        self.window = window
    }
}
