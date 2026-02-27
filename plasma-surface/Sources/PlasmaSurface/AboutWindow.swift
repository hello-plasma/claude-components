import AppKit
import SwiftUI

/// "About Plasma Surface" modal window.
@MainActor
final class AboutWindow {
    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 360)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.contentView = hostingView
        w.title = "About Plasma Surface"
        w.isReleasedWhenClosed = false
        w.center()
        w.level = .floating
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = w
    }
}

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    var body: some View {
        VStack(spacing: 12) {
            if let icon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
            }

            Text("Plasma Surface")
                .font(.system(size: 18, weight: .bold))

            Text("Version \(version)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("Dynamic UI Viewer for Claude")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                AboutLink(
                    icon: "globe",
                    label: "helloplasma.org",
                    url: URL(string: "https://helloplasma.org")!
                )
                AboutLink(
                    icon: "envelope.fill",
                    label: "info@helloplasma.org",
                    url: URL(string: "mailto:info@helloplasma.org")!
                )
                AboutLink(
                    icon: "chevron.left.forwardslash.chevron.right",
                    label: "GitHub",
                    url: URL(string: "https://github.com/hello-plasma/claude-components")!
                )
            }

            Spacer().frame(height: 4)

            Text("\u{00A9} 2026 Lorenzo Toscano. MIT License.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(width: 320, height: 360)
    }
}

/// A clickable link row with SF Symbol icon and pointer cursor.
struct AboutLink: View {
    let icon: String
    let label: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 11))
            }
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
