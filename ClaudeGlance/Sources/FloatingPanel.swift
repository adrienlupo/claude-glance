import AppKit

final class FloatingPanel: NSPanel {
    private let positionKey = "floatingPanelPosition"

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 36),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.frame = NSRect(x: 0, y: 0, width: 300, height: 36)
        visualEffect.autoresizingMask = [.width, .height]

        contentView.frame = visualEffect.bounds
        contentView.autoresizingMask = [.width, .height]
        visualEffect.addSubview(contentView)

        self.contentView = visualEffect
        restorePosition()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        savePosition()
    }

    func savePosition() {
        UserDefaults.standard.set(
            ["x": frame.origin.x, "y": frame.origin.y],
            forKey: positionKey
        )
    }

    private func restorePosition() {
        if let pos = UserDefaults.standard.dictionary(forKey: positionKey),
           let x = pos["x"] as? CGFloat,
           let y = pos["y"] as? CGFloat {
            let point = NSPoint(x: x, y: y)
            if NSScreen.screens.contains(where: { $0.visibleFrame.contains(point) }) {
                setFrameOrigin(point)
                return
            }
        }
        resetToDefaultPosition()
    }

    func resetToDefaultPosition() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.maxX - frame.width - 20
        let y = visibleFrame.maxY - frame.height - 20
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updateSize(width: CGFloat, height: CGFloat) {
        let origin = frame.origin
        let newY = origin.y + frame.height - height
        setFrame(
            NSRect(x: origin.x, y: newY, width: width, height: height),
            display: true,
            animate: true
        )
    }
}
