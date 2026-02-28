import AppKit
import SwiftUI

/// "Settings" window for configuring the WebSocket server.
@MainActor
final class SettingsWindow {
    private var window: NSWindow?
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let appState else { return }

        let settingsView = SettingsView(appState: appState)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 200)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.contentView = hostingView
        w.title = "Settings"
        w.isReleasedWhenClosed = false
        w.center()
        w.level = .floating
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = w
    }
}

struct SettingsView: View {
    let appState: AppState

    @State private var host: String
    @State private var portString: String
    @State private var statusMessage: String?
    @State private var statusOk = true
    @State private var restarting = false

    init(appState: AppState) {
        self.appState = appState
        _host = State(initialValue: appState.currentHost)
        _portString = State(initialValue: String(appState.currentPort))
    }

    private var port: UInt16 {
        UInt16(portString) ?? 0
    }

    private var portValid: Bool {
        port > 3000 && port < 60000
    }

    private var wsURL: String {
        "ws://\(host):\(portString)"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("WebSocket Server")
                .font(.system(size: 14, weight: .semibold))

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Text("Host:")
                        .frame(width: 40, alignment: .trailing)
                    TextField("localhost", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                GridRow {
                    Text("Port:")
                        .frame(width: 40, alignment: .trailing)
                    TextField("9420", text: $portString)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            Text(wsURL)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Text("Clients: \(appState.clientCount)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(statusOk ? .secondary : .secondary)
                        .transition(.opacity)
                }

                Button("Restart") {
                    restarting = true
                    appState.restartServer(host: host, port: port) { success in
                        restarting = false
                        withAnimation {
                            statusOk = success
                            statusMessage = success ? "Server restarted" : "Invalid config. Ignored."
                        }
                        if success {
                            // Sync fields back to actual server values
                            host = appState.currentHost
                            portString = String(appState.currentPort)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { statusMessage = nil }
                        }
                    }
                }
                .controlSize(.regular)
                .disabled(!portValid || restarting)
            }
        }
        .padding(24)
        .frame(width: 360, height: 200)
    }
}
