import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private let store = SessionStore()
    private var iconCache: [NSColor: NSImage] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let initialState: WidgetState = store.sessions.isEmpty ? .empty : .collapsed

        let contentView = NSHostingView(
            rootView: PillContentView(
                store: store,
                initialState: initialState,
                onStateChange: { [weak self] state in
                    self?.updatePanelSize(state: state)
                },
                onHidePanel: { [weak self] in
                    self?.panel.orderOut(nil)
                    self?.updateStatusItemColor()
                }
            )
        )

        panel = FloatingPanel(contentView: contentView)
        panel.orderFront(nil)
        updatePanelSize(state: initialState)

        setupStatusItem()
        updateStatusItemColor()
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
        let color: NSColor = panel.isVisible
            ? NSColor(red: 0.82, green: 0.45, blue: 0.18, alpha: 1.0)
            : NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
        button.image = makeStatusIcon(color: color)
    }

    private func makeStatusIcon(color: NSColor) -> NSImage {
        if let cached = iconCache[color] { return cached }
        guard let logoURL = Bundle.module.url(forResource: "logo-orange", withExtension: "png"),
              let baseImage = NSImage(contentsOf: logoURL) else { return NSImage() }

        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            baseImage.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        iconCache[color] = image
        return image
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
        }
        updateStatusItemColor()
    }

    private func updatePanelSize(state: WidgetState) {
        switch state {
        case .empty:
            panel.updateSize(width: 36, height: 36, cornerRadius: 18)
        case .collapsed:
            let statusCount = store.countsByStatus.count
            let width = max(CGFloat(60), CGFloat(20 + 20 + statusCount * 30 + 10))
            panel.updateSize(width: width, height: 36, cornerRadius: 18)
        case .expanded:
            let rows = min(store.sessions.count, 5)
            let detailHeight = CGFloat(rows) * 26 + 16
            panel.updateSize(width: 280, height: 36 + detailHeight, cornerRadius: 12)
        }
    }
}

struct PillContentView: View {
    let store: SessionStore
    var onStateChange: (WidgetState) -> Void
    var onHidePanel: (() -> Void)?
    @State private var widgetState: WidgetState

    init(
        store: SessionStore,
        initialState: WidgetState = .empty,
        onStateChange: @escaping (WidgetState) -> Void,
        onHidePanel: (() -> Void)? = nil
    ) {
        self.store = store
        self._widgetState = State(initialValue: initialState)
        self.onStateChange = onStateChange
        self.onHidePanel = onHidePanel
    }

    var body: some View {
        PillView(store: store, widgetState: $widgetState, onHidePanel: onHidePanel)
            .onChange(of: widgetState) { _, newValue in
                onStateChange(newValue)
            }
            .onChange(of: store.countsByStatus.count) { _, _ in
                if widgetState == .collapsed {
                    onStateChange(widgetState)
                }
            }
            .onChange(of: store.sessions.count) { _, _ in
                if widgetState == .expanded {
                    onStateChange(widgetState)
                }
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
