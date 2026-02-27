import AppKit
import SwiftUI

/// Manages the menubar status item and plasma window.
@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem
    private let appState: AppState
    private var plasmaWindow: PlasmaWindow?
    private let aboutWindow = AboutWindow()

    init(appState: AppState) {
        self.appState = appState

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Plasma Surface")
            button.action = #selector(statusBarAction(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Wire window show callback
        appState.onShowWindow = { [weak self] in
            self?.showWindow()
        }
    }

    @objc private func statusBarAction(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleWindow()
        }
    }

    private func toggleWindow() {
        if let window = plasmaWindow?.window, window.isVisible {
            window.orderOut(nil)
            appState.windowVisible = false
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        if plasmaWindow == nil {
            plasmaWindow = PlasmaWindow(appState: appState)
        }
        plasmaWindow?.show()
        appState.windowVisible = true
    }

    private func showMenu() {
        let menu = NSMenu()

        let connectedItem = NSMenuItem(
            title: "Clients: \(appState.clientCount)",
            action: nil,
            keyEquivalent: ""
        )
        connectedItem.isEnabled = false
        menu.addItem(connectedItem)

        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(
            title: appState.windowVisible ? "Hide Window" : "Show Window",
            action: #selector(toggleWindowAction),
            keyEquivalent: "w"
        )
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "About Plasma Surface",
            action: #selector(aboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Plasma Surface",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Reset menu so left-click works again
        statusItem.menu = nil
    }

    @objc private func toggleWindowAction() {
        toggleWindow()
    }

    @objc private func aboutAction() {
        aboutWindow.show()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
