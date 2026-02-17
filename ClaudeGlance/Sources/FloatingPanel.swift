import AppKit

extension Notification.Name {
    static let pillHeaderTapped = Notification.Name("pillHeaderTapped")
}

final class FloatingPanel: NSPanel {
    private let positionKey = "floatingPanelPosition"
    private var mouseDownScreenLocation: NSPoint = .zero
    private let containerView = NSView()
    private let visualEffectView = NSVisualEffectView()

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        let cornerRadius = PanelLayout.pillCornerRadius
        let shadowOpacity: Float = 0.25
        let shadowRadius: CGFloat = 8
        let shadowOffset = CGSize(width: 0, height: -2)
        let borderOpacity: CGFloat = 0.15

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        let initialFrame = NSRect(x: 0, y: 0, width: 36, height: 36)

        // Container view provides the shadow that follows the rounded shape
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = cornerRadius
        containerView.layer?.cornerCurve = .continuous
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = shadowOpacity
        containerView.layer?.shadowRadius = shadowRadius
        containerView.layer?.shadowOffset = shadowOffset
        containerView.frame = initialFrame
        containerView.autoresizingMask = [.width, .height]

        // Visual effect view clips content to the rounded shape
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 0.5
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(borderOpacity).cgColor
        visualEffectView.frame = initialFrame
        visualEffectView.autoresizingMask = [.width, .height]

        contentView.frame = visualEffectView.bounds
        contentView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(contentView)
        containerView.addSubview(visualEffectView)

        self.contentView = containerView
        restorePosition()
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownScreenLocation = NSEvent.mouseLocation
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        savePosition()

        let upLocation = NSEvent.mouseLocation
        let distance = hypot(upLocation.x - mouseDownScreenLocation.x,
                             upLocation.y - mouseDownScreenLocation.y)
        let isInHeader = event.locationInWindow.y >= frame.height - PanelLayout.headerHeight

        if distance < 3 && isInHeader {
            NotificationCenter.default.post(name: .pillHeaderTapped, object: nil)
        }
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
        let x = visibleFrame.minX + 20
        let y = visibleFrame.maxY - frame.height - 20
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updateSize(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) {
        let origin = frame.origin
        let newX = origin.x
        let newY = origin.y + frame.height - height

        for layer in [containerView.layer, visualEffectView.layer] {
            guard let layer, layer.cornerRadius != cornerRadius else { continue }
            let animation = CABasicAnimation(keyPath: "cornerRadius")
            animation.fromValue = layer.cornerRadius
            animation.toValue = cornerRadius
            animation.duration = 0.25
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(animation, forKey: "cornerRadius")
            layer.cornerRadius = cornerRadius
        }

        setFrame(
            NSRect(x: newX, y: newY, width: width, height: height),
            display: true,
            animate: true
        )
    }
}
