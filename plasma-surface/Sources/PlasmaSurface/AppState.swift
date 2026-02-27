import Foundation
import AppKit

/// Central state manager wiring PlasmaState <-> WebSocketServer.
@Observable
@MainActor
final class AppState {
    let plasmaState = PlasmaState()
    let wsServer = WebSocketServer(port: 9420)

    /// Whether the plasma window is currently visible.
    var windowVisible = false

    /// Number of connected clients.
    var clientCount: Int { wsServer.clientCount }

    /// Callback invoked when the window should open.
    var onShowWindow: (() -> Void)?

    func start() {
        // PlasmaState → WS: route actions back to connector
        plasmaState.onAction = { [weak self] payload in
            guard let self else { return }
            if let data = try? JSONSerialization.data(withJSONObject: payload),
               let json = String(data: data, encoding: .utf8) {
                self.wsServer.sendToAll(json)
            }
        }

        // PlasmaState → open window when content arrives
        plasmaState.onContentArrived = { [weak self] in
            self?.onShowWindow?()
        }

        // WS → PlasmaState: route incoming messages
        wsServer.onMessage = { [weak self] message in
            guard let self else { return }
            guard let data = message.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                print("[AppState] Failed to parse message")
                return
            }

            Task { @MainActor in
                self.handleMessage(type: type, json: json)
            }
        }

        wsServer.onClientCountChanged = { [weak self] count in
            Task { @MainActor in
                if count == 0 {
                    self?.plasmaState.reset()
                }
                print("[AppState] Connected clients: \(count)")
            }
        }

        // Start WebSocket server
        wsServer.start()
        print("[PlasmaSurface] Started — listening on ws://localhost:9420")
    }

    private func handleMessage(type: String, json: [String: Any]) {
        switch type {
        case "dynamic_ui":
            plasmaState.handleRender(json)

        case "dynamic_ui_update":
            plasmaState.handleUpdate(json)

        case "dynamic_ui_clear":
            plasmaState.handleClear()

        case "command":
            handleCommand(json)

        default:
            print("[AppState] Unknown message type: \(type)")
        }
    }

    private func handleCommand(_ json: [String: Any]) {
        guard let id = json["id"] as? String,
              let command = json["command"] as? String else {
            print("[AppState] Invalid command message")
            return
        }

        let params = json["params"] as? [String: Any] ?? [:]

        switch command {
        case "dynamic_ui.query":
            guard let js = params["js"] as? String else {
                sendCommandResult(id: id, ok: false, error: "Missing 'js' parameter")
                return
            }
            plasmaState.webView?.evaluateJavaScript(js) { [weak self] result, error in
                Task { @MainActor in
                    if let error {
                        self?.sendCommandResult(id: id, ok: false, error: error.localizedDescription)
                    } else {
                        self?.sendCommandResult(id: id, ok: true, result: result)
                    }
                }
            }

        case "dynamic_ui.screenshot":
            guard let webView = plasmaState.webView else {
                sendCommandResult(id: id, ok: false, error: "No active WebView")
                return
            }
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { [weak self] image, error in
                Task { @MainActor in
                    if let error {
                        self?.sendCommandResult(id: id, ok: false, error: error.localizedDescription)
                        return
                    }
                    guard let image,
                          let tiff = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiff),
                          let pngData = bitmap.representation(using: .png, properties: [:]) else {
                        self?.sendCommandResult(id: id, ok: false, error: "Failed to capture screenshot")
                        return
                    }
                    let base64 = pngData.base64EncodedString()
                    self?.sendCommandResult(id: id, ok: true, result: ["image": base64, "mimeType": "image/png"])
                }
            }

        default:
            sendCommandResult(id: id, ok: false, error: "Unknown command: \(command)")
        }
    }

    private func sendCommandResult(id: String, ok: Bool, result: Any? = nil, error: String? = nil) {
        var payload: [String: Any] = [
            "type": "command_result",
            "id": id,
            "ok": ok,
        ]
        if let result { payload["result"] = result }
        if let error { payload["error"] = error }

        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            wsServer.sendToAll(json)
        }
    }
}

import WebKit
