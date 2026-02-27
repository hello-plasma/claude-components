import SwiftUI
import WebKit

/// WKWebView subclass that accepts the first mouse click even when the window
/// is not the key window. Without this, clicking a button in a background Plasma
/// window first activates the window and swallows the click — the user has to
/// click twice.
class FirstClickWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

/// SwiftUI wrapper for a WKWebView that renders Dynamic UI (Plasma) content.
///
/// Communication:
/// - Swift → JS: `evaluateJavaScript()` for incremental updates
/// - JS → Swift: `WKScriptMessageHandler` for user actions
struct PlasmaWebView: NSViewRepresentable {
    let plasmaState: PlasmaState

    func makeCoordinator() -> Coordinator {
        Coordinator(plasmaState: plasmaState)
    }

    func makeNSView(context: Context) -> FirstClickWebView {
        let config = WKWebViewConfiguration()
        let userContent = config.userContentController

        // Register message handlers for JS → Swift communication
        userContent.add(context.coordinator, name: "heraAction")
        userContent.add(context.coordinator, name: "heraReady")
        userContent.add(context.coordinator, name: "heraLog")

        let webView = FirstClickWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        webView.navigationDelegate = context.coordinator

        // Store reference so PlasmaState can push updates
        plasmaState.webView = webView

        return webView
    }

    func updateNSView(_ webView: FirstClickWebView, context: Context) {
        // Ensure reference stays current
        if plasmaState.webView !== webView {
            plasmaState.webView = webView
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let plasmaState: PlasmaState

        init(plasmaState: PlasmaState) {
            self.plasmaState = plasmaState
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            Task { @MainActor in
                switch message.name {
                case "heraAction":
                    print("[Plasma] heraAction received from JS")
                    guard let body = message.body as? String,
                          let data = body.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("[Plasma] heraAction: failed to parse body")
                        return
                    }

                    let action = PlasmaAction(
                        activityId: json["activityId"] as? String ?? "",
                        type: json["type"] as? String ?? "",
                        data: json["data"] as? [String: Any],
                        context: json["context"] as? [String: Any]
                    )
                    print("[Plasma] Routing action: \(action.activityId) / \(action.type)")
                    plasmaState.routeAction(action)

                case "heraReady":
                    print("[Plasma] WebView ready")

                case "heraLog":
                    if let text = message.body as? String {
                        print("[Plasma/JS] \(text)")
                    }

                default:
                    break
                }
            }
        }

        // Allow loading inline content
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            // Allow initial load and same-document navigation
            if navigationAction.navigationType == .other || navigationAction.navigationType == .reload {
                return .allow
            }
            // External links: open in default browser
            if let url = navigationAction.request.url, url.scheme == "https" || url.scheme == "http" {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}

/// Standalone Plasma Surface window content.
struct PlasmaSurfaceView: View {
    let plasmaState: PlasmaState

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1))
                .ignoresSafeArea()

            if plasmaState.hasContent {
                PlasmaWebView(plasmaState: plasmaState)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                    Text("Plasma Surface")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Waiting for Dynamic UI content")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
