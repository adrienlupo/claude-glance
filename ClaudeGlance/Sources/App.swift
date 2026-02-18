import AppKit
import os
import ServiceManagement
import SwiftUI

enum PanelLayout {
    static let headerHeight: CGFloat = 36
    static let pillCornerRadius: CGFloat = 18
    static let expandedCornerRadius: CGFloat = 12
    static let expandedWidth: CGFloat = 280
    static let rowHeight: CGFloat = 26
    static let detailPadding: CGFloat = 16
    static let minCollapsedWidth: CGFloat = 60
    static let emptyPillWidth: CGFloat = 44
    static let maxVisibleRows = 5
    // Collapsed width: logo padding + logo + (count per status * dot+number width) + trailing
    static let collapsedBasePadding: CGFloat = 20 + 20 + 10
    static let collapsedPerStatusWidth: CGFloat = 30
}

private enum MenuBarColors {
    static let active = NSColor(red: 0.82, green: 0.45, blue: 0.18, alpha: 1.0)
    static let inactive = NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "claude-glance", category: "app")
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

        let shapesItem = NSMenuItem(
            title: "Use Shapes for Status",
            action: #selector(toggleShapesForStatus),
            keyEquivalent: ""
        )
        shapesItem.target = self
        shapesItem.state = UserDefaults.standard.bool(forKey: "useShapesForStatus") ? .on : .off
        menu.addItem(shapesItem)

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

    @objc private func toggleShapesForStatus() {
        let key = "useShapesForStatus"
        let current = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(!current, forKey: key)
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
            Self.logger.error("Launch at login toggle failed: \(error)")
        }
    }

    private func updateStatusItemColor() {
        guard let button = statusItem?.button else { return }
        let color: NSColor = panel.isVisible
            ? MenuBarColors.active
            : MenuBarColors.inactive
        button.image = makeStatusIcon(color: color)
    }

    private func makeStatusIcon(color: NSColor) -> NSImage {
        if let cached = iconCache[color] { return cached }
        guard let logoURL = Bundle.main.url(forResource: "logo-orange", withExtension: "png"),
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
        let h = PanelLayout.headerHeight
        switch state {
        case .empty:
            panel.updateSize(width: PanelLayout.emptyPillWidth, height: h, cornerRadius: PanelLayout.pillCornerRadius)
        case .collapsed:
            let statusCount = CGFloat(store.countsByStatus.count)
            let width = max(PanelLayout.minCollapsedWidth,
                            PanelLayout.collapsedBasePadding + statusCount * PanelLayout.collapsedPerStatusWidth)
            panel.updateSize(width: width, height: h, cornerRadius: PanelLayout.pillCornerRadius)
        case .expanded:
            let rows = CGFloat(min(max(store.sessions.count, 1), PanelLayout.maxVisibleRows))
            let detailHeight = rows * PanelLayout.rowHeight + PanelLayout.detailPadding
            panel.updateSize(width: PanelLayout.expandedWidth, height: h + detailHeight,
                             cornerRadius: PanelLayout.expandedCornerRadius)
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

@MainActor
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
