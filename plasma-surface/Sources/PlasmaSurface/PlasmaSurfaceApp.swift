import SwiftUI

@main
struct PlasmaSurfaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty — window is managed by StatusBarController
        Settings { EmptyView() }
            .commands {
                AppMenuCommands(
                    onAbout: { [appDelegate] in appDelegate.showAbout() },
                    onSettings: { [appDelegate] in appDelegate.showSettings() }
                )
            }
    }
}

/// Menu commands for the app menu bar (Plasma Surface > About / Settings).
struct AppMenuCommands: Commands {
    let onAbout: () -> Void
    let onSettings: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Plasma Surface") {
                onAbout()
            }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                onSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menubar status item first (while still .accessory)
        statusBarController = StatusBarController(appState: appState)
        appState.start()

        // Then switch to .regular to show Dock icon
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)

            // Set Dock icon from bundle resources
            if let url = StatusBarController.resourceURL(name: "AppIcon", ext: "icns"),
               let icon = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = icon
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Dock icon clicked — bring window to foreground
        appState.onShowWindow?()
        return true
    }

    func showAbout() {
        statusBarController?.showAbout()
    }

    func showSettings() {
        statusBarController?.showSettings()
    }
}
