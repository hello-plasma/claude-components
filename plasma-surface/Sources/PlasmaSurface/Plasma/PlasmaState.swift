import Foundation
import WebKit

/// Payload for a Dynamic UI render (maps to wire message type "dynamic_ui").
struct PlasmaPayload {
    let html: String
    let css: String
    let js: String
    let activities: [[String: Any]]
}

/// User action originating from a Dynamic UI surface.
struct PlasmaAction {
    let activityId: String
    let type: String
    let data: [String: Any]?
    let context: [String: Any]?
}

/// Observable state for the Plasma Surface (Dynamic UI).
///
/// Manages:
/// - Current payload (HTML/CSS/JS)
/// - WKWebView reference for incremental updates
/// - Action routing back to the gateway
@Observable
@MainActor
final class PlasmaState {
    /// Whether the surface currently has rendered content.
    private(set) var hasContent = false

    /// The WKWebView used for rendering. Set by PlasmaWebView coordinator.
    /// When set, automatically loads any pending content.
    weak var webView: WKWebView? {
        didSet {
            if let webView, let srcdoc = pendingSrcdoc {
                pendingSrcdoc = nil
                webView.loadHTMLString(srcdoc, baseURL: nil)
            }
        }
    }

    /// Buffered HTML waiting for the WKWebView to be created.
    private var pendingSrcdoc: String?

    /// Origin channel for routing actions back (from wire message).
    private var originChannel: String?

    /// Origin chatId for routing actions back (from wire message).
    private var originChatId: String?

    /// Callback to send user actions back through the gateway.
    var onAction: (([String: Any]) -> Void)?

    /// Callback to request the plasma window to open.
    var onContentArrived: (() -> Void)?

    // MARK: - Incoming messages

    /// Handle a full render payload (`type: "dynamic_ui"`).
    func handleRender(_ json: [String: Any]) {
        let html = json["html"] as? String ?? ""
        let css = json["css"] as? String ?? ""
        let js = json["js"] as? String ?? ""
        let activities = json["activities"] as? [[String: Any]] ?? []

        // Store origin routing info for action replies
        originChannel = json["channel"] as? String
        originChatId = json["chatId"] as? String

        let srcdoc = generateSrcdoc(html: html, css: css, js: js, activities: activities)
        hasContent = true

        if let webView {
            webView.loadHTMLString(srcdoc, baseURL: nil)
        } else {
            // WebView not yet created — buffer until it's assigned
            pendingSrcdoc = srcdoc
        }
        onContentArrived?()
    }

    /// Handle an incremental update (`type: "dynamic_ui_update"`).
    func handleUpdate(_ json: [String: Any]) {
        // Update origin routing if provided
        if let ch = json["channel"] as? String { originChannel = ch }
        if let cid = json["chatId"] as? String { originChatId = cid }

        guard let js = json["js"] as? String, !js.isEmpty else { return }
        webView?.evaluateJavaScript(js) { _, error in
            if let error {
                print("[Plasma] JS update error: \(error)")
            }
        }
    }

    /// Handle clear (`type: "dynamic_ui_clear"`).
    func handleClear() {
        hasContent = false
        webView?.loadHTMLString("", baseURL: nil)
    }

    /// Route an action from the WebView back to the gateway.
    func routeAction(_ action: PlasmaAction) {
        var payload: [String: Any] = [
            "type": "dynamic_ui_action",
            "action": [
                "activityId": action.activityId,
                "type": action.type,
                "data": action.data as Any,
                "context": action.context as Any,
            ] as [String: Any],
        ]
        // Include origin routing so the server can route to the correct session
        if let ch = originChannel { payload["channel"] = ch }
        if let cid = originChatId { payload["chatId"] = cid }

        print("[Plasma] routeAction → channel=\(originChannel ?? "nil") chatId=\(originChatId ?? "nil") onAction=\(onAction != nil ? "set" : "nil")")
        onAction?(payload)
    }

    /// Reset state (e.g. on disconnect).
    func reset() {
        hasContent = false
        pendingSrcdoc = nil
        originChannel = nil
        originChatId = nil
        webView?.loadHTMLString("", baseURL: nil)
    }

    // MARK: - HTML generation

    /// Generate the full HTML document to load into the WKWebView.
    /// Mirrors ElectroNode's `generateIframeSrcdoc()`.
    private func generateSrcdoc(html: String, css: String, js: String, activities: [[String: Any]]) -> String {
        let activitiesJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: activities),
           let str = String(data: data, encoding: .utf8) {
            activitiesJSON = str
        } else {
            activitiesJSON = "[]"
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              background: #0f0f0f;
              color: #e5e5e5;
              padding: 16px;
              overflow-x: hidden;
            }
            \(css)
          </style>
        </head>
        <body>
          \(html)
          <script>
          (function() {
            // Bridge console to Swift
            var _log = console.log, _warn = console.warn, _err = console.error;
            function bridgeLog(level, args) {
              try {
                window.webkit.messageHandlers.heraLog.postMessage(
                  '[' + level + '] ' + Array.prototype.slice.call(args).map(function(a) {
                    return typeof a === 'object' ? JSON.stringify(a) : String(a);
                  }).join(' ')
                );
              } catch(e) {}
            }
            console.log = function() { _log.apply(console, arguments); bridgeLog('LOG', arguments); };
            console.warn = function() { _warn.apply(console, arguments); bridgeLog('WARN', arguments); };
            console.error = function() { _err.apply(console, arguments); bridgeLog('ERROR', arguments); };

            var activities = \(activitiesJSON);

            // Global action sender — defined early so inline handlers can use it
            window.sendAction = function(activityId, type, data) {
              console.log('[Plasma] sendAction:', activityId, type);
              try {
                window.webkit.messageHandlers.heraAction.postMessage(JSON.stringify({
                  activityId: activityId,
                  type: type,
                  data: data,
                  context: data ? data.context : undefined
                }));
              } catch(e) {
                console.error('[Plasma] No webkit handler:', e);
              }
            };

            function setupActivities() {
              console.log('[Plasma] Setting up activities:', activities.length);
              activities.forEach(function(activity) {
                var el = document.getElementById(activity.id);
                if (!el) {
                  console.warn('[Plasma] Activity element not found:', activity.id);
                  return;
                }
                console.log('[Plasma] Binding activity:', activity.id, activity.type);

                if (activity.type === 'button') {
                  el.addEventListener('click', function(e) {
                    e.preventDefault();
                    var provided = undefined;
                    if (activity.dataProvider) {
                      try { provided = eval('(' + activity.dataProvider + ')'); } catch(err) {
                        console.error('[Plasma] dataProvider error:', err);
                      }
                    }
                    sendAction(activity.id, 'click', { context: activity.context, provided: provided });
                  });
                } else if (activity.type === 'input') {
                  el.addEventListener('change', function(e) {
                    var provided = undefined;
                    if (activity.dataProvider) {
                      try { provided = eval('(' + activity.dataProvider + ')'); } catch(err) {
                        console.error('[Plasma] dataProvider error:', err);
                      }
                    }
                    sendAction(activity.id, 'change', {
                      value: e.target.value,
                      context: activity.context,
                      provided: provided
                    });
                  });
                } else if (activity.type === 'canvas' || activity.type === 'custom') {
                  el.dataset.activityId = activity.id;
                  el.dataset.activityContext = JSON.stringify(activity.context || {});
                }
              });

              try { window.webkit.messageHandlers.heraReady.postMessage('ready'); } catch(e) {}
            }

            // Handle both cases: DOM still loading or already loaded
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', setupActivities);
            } else {
              setupActivities();
            }

            \(js)
          })();
          </script>
        </body>
        </html>
        """
    }
}
