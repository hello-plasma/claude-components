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
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 340)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 340),
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

            Text("Dynamic UI viewer for Claude.\nRenders HTML/CSS/JS interfaces\non your desktop.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Divider()
                .padding(.horizontal, 24)

            VStack(spacing: 6) {
                Link("helloplasma.org", destination: URL(string: "https://helloplasma.org")!)
                    .font(.system(size: 11))
                Link("info@helloplasma.org", destination: URL(string: "mailto:info@helloplasma.org")!)
                    .font(.system(size: 11))
                Link("GitHub", destination: URL(string: "https://github.com/hello-plasma/claude-components")!)
                    .font(.system(size: 11))
            }

            Spacer().frame(height: 4)

            Text("\u{00A9} 2026 Lorenzo Toscano. All rights reserved.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(width: 320, height: 340)
    }
}
