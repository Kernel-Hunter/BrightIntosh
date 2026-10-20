//
//  BrightnessHUD.swift
//  BrightIntosh
//
//  Square Liquid Glass popup that shows the brightness bar, nits and
//  percentage. Appearance comes from KeysSettings and from the system
//  accessibility settings (Reduce Transparency, Increase Contrast,
//  Reduce Motion).
//
//  Liquid Glass only renders its lensing while its window is key, so the
//  panel takes key status without activating the app. Keystrokes that land
//  on it are re-posted so typing in the previous app is not lost.
//

import Cocoa

struct HUDConfig: Equatable {
    var side: CGFloat
    var position: HUDPosition
    var style: HUDStyle
    var tint: CGFloat
    var showIcon: Bool
    var showNits: Bool
    var showBar: Bool
    var showPercent: Bool
    var largeText: Bool
    var border: Bool
    var duration: TimeInterval
    var animate: Bool

    static let baseSide: CGFloat = 190

    @MainActor
    static func current() -> HUDConfig {
        let s = KeysSettings.shared
        let workspace = NSWorkspace.shared
        let followTransparency = s.followSystemTransparency
        let reduceTransparency = followTransparency && workspace.accessibilityDisplayShouldReduceTransparency
        let increaseContrast = followTransparency && workspace.accessibilityDisplayShouldIncreaseContrast
        let reduceMotion = s.followSystemMotion && workspace.accessibilityDisplayShouldReduceMotion

        return HUDConfig(
            side: baseSide * s.hudSize.scale,
            position: s.hudPosition,
            style: (reduceTransparency || increaseContrast) ? .solid : s.hudStyle,
            tint: CGFloat(s.hudTint),
            showIcon: s.showIcon,
            showNits: s.showNits,
            showBar: s.showBar,
            showPercent: s.showPercent,
            largeText: s.largeText,
            border: s.highContrastBorder || increaseContrast,
            duration: s.hudDuration,
            animate: !reduceMotion
        )
    }
}

@MainActor
final class BrightnessHUD {
    private var panel: NSPanel?
    private var builtConfig: HUDConfig?
    private let icon = NSImageView()
    private let nitsLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let bar = HUDBarView()
    private var hideWork: DispatchWorkItem?

    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    func show(nits: Float, fraction: Float, on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else { return }
        let config = HUDConfig.current()
        if config != builtConfig || panel == nil { build(config) }
        guard let panel else { return }
        update(nits: nits, fraction: fraction)

        panel.setFrameOrigin(origin(for: config, panel: panel, screen: screen))
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        // Liquid Glass only looks like glass in the key window.
        panel.makeKey()

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide(animated: config.animate) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration, execute: work)
    }

    func update(nits: Float, fraction: Float) {
        let value = formatter.string(from: NSNumber(value: Int(nits.rounded()))) ?? "\(Int(nits))"
        let percent = Int((fraction * 100).rounded())
        nitsLabel.stringValue = String(localized: "\(value) nits")
        percentLabel.stringValue = "\(percent)%"
        bar.fraction = CGFloat(min(max(fraction, 0), 1))
        panel?.contentView?.setAccessibilityValue(String(localized: "\(value) nits, \(percent) percent"))
    }

    private func hide(animated: Bool) {
        guard let panel else { return }
        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    private func origin(for config: HUDConfig, panel: NSPanel, screen: NSScreen) -> NSPoint {
        let size = panel.frame.size
        let full = screen.frame
        let visible = screen.visibleFrame
        switch config.position {
        case .bottomCenter: return NSPoint(x: full.midX - size.width / 2, y: full.minY + 110)
        case .center: return NSPoint(x: full.midX - size.width / 2, y: full.midY - size.height / 2)
        case .topCenter: return NSPoint(x: full.midX - size.width / 2, y: visible.maxY - size.height - 24)
        case .topRight: return NSPoint(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24)
        }
    }

    // MARK: Building

    private func build(_ config: HUDConfig) {
        panel?.orderOut(nil)
        builtConfig = config

        let side = config.side
        let scale = side / HUDConfig.baseSide
        let textBoost: CGFloat = config.largeText ? 1.2 : 1
        let size = NSSize(width: side, height: side)
        let radius = 44 * scale

        let panel = HUDPanel(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: true)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.wantsLayer = true
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.staticText)
        content.setAccessibilityLabel(String(localized: "Brightness"))

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = NSSize(width: 0, height: -1)

        icon.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)
        icon.contentTintColor = .white
        icon.symbolConfiguration = .init(pointSize: 54 * scale * textBoost, weight: .regular)
        icon.shadow = shadow

        let weight: NSFont.Weight = config.largeText ? .bold : .semibold
        nitsLabel.font = .monospacedDigitSystemFont(ofSize: 28 * scale * textBoost, weight: weight)
        nitsLabel.textColor = .white
        nitsLabel.alignment = .center
        nitsLabel.shadow = shadow

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 15 * scale * textBoost, weight: config.largeText ? .bold : .medium)
        percentLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        percentLabel.alignment = .center
        percentLabel.shadow = shadow

        var rows: [NSView] = []
        if config.showIcon { rows.append(icon) }
        if config.showNits { rows.append(nitsLabel) }
        if config.showBar { rows.append(bar) }
        if config.showPercent { rows.append(percentLabel) }

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10 * scale
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        var constraints = [
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ]
        if config.showBar {
            bar.translatesAutoresizingMaskIntoConstraints = false
            constraints += [
                bar.widthAnchor.constraint(equalToConstant: side - 48 * scale),
                bar.heightAnchor.constraint(equalToConstant: 8 * scale),
            ]
        }
        NSLayoutConstraint.activate(constraints)

        if config.border {
            content.layer?.borderWidth = 2
            content.layer?.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor
            content.layer?.cornerRadius = radius
        }

        switch config.style {
        case .solid:
            content.layer?.backgroundColor = NSColor(white: 0.13, alpha: 1).cgColor
            content.layer?.cornerRadius = radius
            content.layer?.masksToBounds = true
            panel.contentView = content
        case .glassClear, .glassRegular:
            if #available(macOS 26.0, *) {
                let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
                glass.cornerRadius = radius
                glass.style = config.style == .glassClear ? .clear : .regular
                // A light dark tint keeps white text readable over bright content.
                if config.tint > 0 { glass.tintColor = NSColor.black.withAlphaComponent(config.tint) }
                glass.contentView = content
                panel.contentView = glass
            } else {
                let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
                effect.material = .hudWindow
                effect.blendingMode = .behindWindow
                effect.state = .active
                effect.wantsLayer = true
                effect.layer?.cornerRadius = radius
                effect.layer?.masksToBounds = true
                effect.addSubview(content)
                panel.contentView = effect
            }
        }
        self.panel = panel
    }
}

/// Key-capable HUD panel. Keystrokes that land on it are re-posted.
private final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) { forward(event) }
    override func keyUp(with event: NSEvent) { forward(event) }

    private func forward(_ event: NSEvent) {
        orderOut(nil)
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}

private final class HUDBarView: NSView {
    var fraction: CGFloat = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        NSColor.white.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        var fill = bounds
        fill.size.width = bounds.width * min(max(fraction, 0), 1)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()
    }
}
