import AppKit
import SwiftUI

/// Manages the menubar status item and plasma window.
@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem
    private let appState: AppState
    private var plasmaWindow: PlasmaWindow?
    private let aboutWindow = AboutWindow()
    private var settingsWindow: SettingsWindow?

    init(appState: AppState) {
        self.appState = appState

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let icon = Self.loadMenubarIcon()
            button.image = icon
            // Text fallback if icon is nil or fails to render
            if button.image == nil {
                button.title = "⬡"
            }
            button.action = #selector(statusBarAction(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem.isVisible = true

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

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    /// Load menubar icon from app bundle Resources or fallback.
    private static func loadMenubarIcon() -> NSImage {
        if let url = Self.resourceURL(name: "menubar-icon", ext: "png"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            return img
        }
        // Fallback SF Symbol
        return NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Plasma Surface")!
    }

    /// Find a resource file searching multiple locations.
    static func resourceURL(name: String, ext: String) -> URL? {
        let filename = "\(name).\(ext)"

        // 1. Bundle.main resource lookup
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }

        // 2. Bundle.main.resourceURL directory
        if let resourceDir = Bundle.main.resourceURL {
            let candidate = resourceDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // 3. Executable-relative: Contents/MacOS/../Resources/
        if let execURL = Bundle.main.executableURL {
            let resourcesDir = execURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
            let candidate = resourcesDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // 4. Process path (handles App Translocation)
        let processPath = ProcessInfo.processInfo.arguments[0]
        let processURL = URL(fileURLWithPath: processPath)
        let resourcesDir = processURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
        let candidate = resourcesDir.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        return nil
    }

    @objc private func aboutAction() {
        showAbout()
    }

    @objc private func settingsAction() {
        showSettings()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    func showAbout() {
        aboutWindow.show()
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(appState: appState)
        }
        settingsWindow?.show()
    }
}
