import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private let store = SessionStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = NSHostingView(
            rootView: PillContentView(store: store) { [weak self] expanded in
                self?.updatePanelSize(expanded: expanded)
            }
        )

        panel = FloatingPanel(contentView: contentView)
        panel.orderFront(nil)

        setupStatusItem()
        startObservingStatus()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = makeStatusIcon(color: .systemGray)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Claude Glance",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
    }

    private func startObservingStatus() {
        withObservationTracking {
            _ = store.worstStatus
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                self?.updateStatusItemColor()
                self?.startObservingStatus()
            }
        }
    }

    private func updateStatusItemColor() {
        guard let button = statusItem?.button else { return }
        button.image = makeStatusIcon(color: store.worstStatus.nsColor)
    }

    private func makeStatusIcon(color: NSColor) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let center = CGPoint(x: size / 2, y: size / 2)
            let rayCount = 6
            let innerRadius: CGFloat = 1.8
            let outerRadius: CGFloat = 7.0
            let rayWidth: CGFloat = 1.8
            let dotRadius: CGFloat = 1.4

            color.setFill()

            // Central dot
            NSBezierPath(ovalIn: NSRect(
                x: center.x - innerRadius,
                y: center.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            )).fill()

            // Rays with end dots
            for i in 0..<rayCount {
                let angle = CGFloat(i) * (.pi * 2.0 / CGFloat(rayCount)) - .pi / 2
                let startDist: CGFloat = 3.0
                let cosA = cos(angle)
                let sinA = sin(angle)

                let startX = center.x + cosA * startDist
                let startY = center.y + sinA * startDist
                let endX = center.x + cosA * outerRadius
                let endY = center.y + sinA * outerRadius

                let perpX = -sinA * (rayWidth / 2)
                let perpY = cosA * (rayWidth / 2)

                let ray = NSBezierPath()
                ray.move(to: NSPoint(x: startX + perpX, y: startY + perpY))
                ray.line(to: NSPoint(x: endX + perpX, y: endY + perpY))
                ray.line(to: NSPoint(x: endX - perpX, y: endY - perpY))
                ray.line(to: NSPoint(x: startX - perpX, y: startY - perpY))
                ray.close()
                ray.fill()

                NSBezierPath(ovalIn: NSRect(
                    x: endX - dotRadius,
                    y: endY - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
        }
    }

    private func updatePanelSize(expanded: Bool) {
        if expanded {
            let rows = min(store.sessions.count, 5)
            let detailHeight = CGFloat(rows) * 26 + 16
            panel.updateSize(width: 300, height: 36 + detailHeight)
        } else {
            panel.updateSize(width: 300, height: 36)
        }
    }
}

struct PillContentView: View {
    let store: SessionStore
    var onExpandChange: (Bool) -> Void
    @State private var isExpanded = false

    var body: some View {
        PillView(store: store, isExpanded: $isExpanded)
            .onChange(of: isExpanded) { _, newValue in
                onExpandChange(newValue)
            }
    }
}

@main
struct ClaudeGlanceApp {
    static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = appDelegate
        app.run()
    }
}
