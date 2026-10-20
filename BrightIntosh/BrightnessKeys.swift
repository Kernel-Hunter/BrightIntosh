//
//  BrightnessKeys.swift
//  BrightIntosh
//
//  Owns the hardware brightness keys on the built-in display while the boost
//  is active. One continuous scale in nits: the native slider first, then the
//  XDR boost up to the panel peak (~1600 nits). See BrightnessCurve.
//
//  - The event tap runs on its own thread. The pass/swallow decision never
//    touches main-actor state.
//  - A key press only moves a target. A display-link ramp eases toward it and
//    writes the system brightness and the gamma boost every frame.
//  - BrightnessHUD shows the bar, nits and percentage.
//
//  Needs the Accessibility permission to take over the keys.
//

import Cocoa
import ApplicationServices
import Combine
import OSLog
import QuartzCore

private let nxKeyTypeBrightnessUp = 2
private let nxKeyTypeBrightnessDown = 3
private let nxSubtypeAuxControlButtons: Int16 = 8

private let keysLog = Logger(subsystem: "de.brightintosh.app", category: "keys")

/// Read by the tap thread, written by the main thread.
private final class KeyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var intercept: Bool {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

@MainActor
final class BrightnessKeys: NSObject {
    static let shared = BrightnessKeys()

    nonisolated private static let gate = KeyGate()
    nonisolated(unsafe) private static var tapPort: CFMachPort?

    private let settings = KeysSettings.shared
    private weak var manager: (any BrightnessManaging)?
    private var started = false
    private var promptedForAccess = false
    private var warnedAboutAccess = false
    private var cancellables = Set<AnyCancellable>()

    private let displayServices = DisplayServicesBridge()
    private let hud = BrightnessHUD()

    private var currentNits: Float = 0
    private var targetNits: Float = 0
    private var lastLevel: Float = -1
    private var lastBoost: Float = -1
    private var link: CADisplayLink?
    private var fallbackTimer: Timer?
    private var rampDisplayId: CGDirectDisplayID?

    func start(manager: (any BrightnessManaging)?) {
        guard !started else { return }
        self.manager = manager

        let trusted = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": !promptedForAccess] as CFDictionary
        )
        promptedForAccess = true
        guard trusted else {
            keysLog.notice("Accessibility permission missing, retrying")
            if !warnedAboutAccess {
                warnedAboutAccess = true
                showAccessibilityWarning()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.start(manager: manager) }
            return
        }
        started = true
        keysLog.notice("Accessibility granted, starting event tap")

        if settings.startAtNativeRange { BrightIntoshSettings.shared.brightness = 0 }

        BrightIntoshSettings.shared.addListener(setting: "brightintoshActive") { self.refreshGate() }
        settings.$keysEnabled.sink { [weak self] _ in
            // @Published fires before the value changes; read it on the next turn.
            DispatchQueue.main.async { self?.refreshGate() }
        }.store(in: &cancellables)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { self.refreshGate() } }
        refreshGate()

        let thread = Thread { Self.runTap() }
        thread.name = "BrightnessKeys.tap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// Shows the popup with the current state, for the settings preview.
    func previewHUD() {
        guard let displayId = builtInDisplayId(), let screen = screen(for: displayId) else { return }
        let curve = curve(for: screen)
        let level = displayServices.brightness(displayId) ?? 1
        let nits = min(curve.nits(level: level, boost: BrightIntoshSettings.shared.brightness), curve.maxNits)
        hud.show(nits: nits, fraction: curve.fraction(nits: nits), on: screen)
    }

    private func showAccessibilityWarning() {
        let alert = NSAlert()
        alert.messageText = String(localized: "BrightIntosh needs Accessibility access")
        alert.informativeText = String(localized: "It uses it to take over the brightness keys. In System Settings > Privacy & Security > Accessibility, remove BrightIntosh with the minus button, add it again, and switch it on.")
        alert.addButton(withTitle: String(localized: "Open Settings"))
        alert.addButton(withTitle: String(localized: "Later"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshGate() {
        Self.gate.intercept = BrightIntoshSettings.shared.brightintoshActive
            && settings.keysEnabled
            && builtInDisplayId() != nil
            && displayServices.available
        keysLog.debug("gate intercept=\(Self.gate.intercept)")
    }

    // MARK: Tap thread

    nonisolated private static func runTap() {
        let mask: CGEventMask = 1 << 14 // NX_SYSDEFINED
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let port = BrightnessKeys.tapPort { CGEvent.tapEnable(tap: port, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard BrightnessKeys.gate.intercept,
                  let ns = NSEvent(cgEvent: event),
                  ns.type == .systemDefined,
                  ns.subtype.rawValue == nxSubtypeAuxControlButtons else {
                return Unmanaged.passUnretained(event)
            }
            let keyCode = (ns.data1 & 0xFFFF0000) >> 16
            let keyState = (ns.data1 & 0xFF00) >> 8
            guard keyCode == nxKeyTypeBrightnessUp || keyCode == nxKeyTypeBrightnessDown else {
                return Unmanaged.passUnretained(event)
            }
            if keyState == 0xA {
                let up = keyCode == nxKeyTypeBrightnessUp
                let fine = event.flags.contains(.maskShift) && event.flags.contains(.maskAlternate)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { BrightnessKeys.shared.press(up: up, fine: fine) }
                }
            }
            return nil
        }

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) else {
            keysLog.error("Could not create event tap")
            return
        }
        tapPort = port
        keysLog.notice("Event tap created")
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        CFRunLoopRun()
    }

    // MARK: Key handling (main thread)

    private func curve(for screen: NSScreen) -> BrightnessCurve {
        BrightnessCurve(
            peakNits: panelPeakNits,
            referenceEdr: getScreenRefGamma(screen).0,
            encodingGamma: boostEncodingGamma,
            maxNits: Float(settings.maxNits)
        )
    }

    private var reduceMotion: Bool {
        settings.followSystemMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func press(up: Bool, fine: Bool) {
        guard let displayId = builtInDisplayId(),
              let screen = screen(for: displayId),
              let system = displayServices.brightness(displayId) else { return }
        let curve = curve(for: screen)

        if link == nil && fallbackTimer == nil {
            let boost = BrightIntoshSettings.shared.brightness
            currentNits = min(curve.nits(level: system, boost: boost), curve.maxNits)
            targetNits = currentNits
            lastLevel = system
            lastBoost = boost
        }

        targetNits = curve.stepped(
            from: targetNits,
            up: up,
            nativeSteps: settings.nativeSteps,
            boostStepNits: Float(settings.boostStepNits),
            fineDivisor: fine ? Float(settings.fineDivisor) : 1
        )
        rampDisplayId = displayId

        if settings.hudEnabled {
            hud.show(nits: currentNits, fraction: curve.fraction(nits: currentNits), on: screen)
        }

        if settings.easeMilliseconds == 0 || reduceMotion {
            advance(dt: 1, instant: true)
        } else {
            startRamp(on: screen)
        }
    }

    // MARK: Ramp

    private func startRamp(on screen: NSScreen) {
        guard link == nil, fallbackTimer == nil else { return }
        if #available(macOS 14.0, *) {
            let link = screen.displayLink(target: self, selector: #selector(displayLinkTick(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        } else {
            fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { _ in
                MainActor.assumeIsolated { self.advance(dt: 1.0 / 120.0) }
            }
        }
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        advance(dt: Float(max(link.targetTimestamp - link.timestamp, 1.0 / 240.0)))
    }

    private func advance(dt: Float, instant: Bool = false) {
        guard let displayId = rampDisplayId, let screen = screen(for: displayId) else {
            stopRamp()
            return
        }
        let curve = curve(for: screen)
        if instant {
            currentNits = targetNits
        } else {
            let tau = Float(settings.easeMilliseconds) / 1000
            currentNits += (targetNits - currentNits) * (1 - exp(-dt / tau))
            if abs(targetNits - currentNits) < 0.5 { currentNits = targetNits }
        }
        let finished = currentNits == targetNits

        apply(nits: currentNits, displayId: displayId, curve)
        if settings.hudEnabled {
            if instant {
                hud.show(nits: currentNits, fraction: curve.fraction(nits: currentNits), on: screen)
            } else {
                hud.update(nits: currentNits, fraction: curve.fraction(nits: currentNits))
            }
        }

        if finished {
            stopRamp()
            // Persist the final boost and let the normal path settle.
            BrightIntoshSettings.shared.brightness = curve.split(nits: currentNits).boost
            announce(nits: currentNits, fraction: curve.fraction(nits: currentNits))
        }
    }

    private func stopRamp() {
        link?.invalidate()
        link = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    private func apply(nits: Float, displayId: CGDirectDisplayID, _ curve: BrightnessCurve) {
        let (level, boost) = curve.split(nits: nits)
        if abs(level - lastLevel) > 0.0003 {
            displayServices.setBrightness(displayId, level)
            lastLevel = level
        }
        if abs(boost - lastBoost) > 0.0003 {
            lastBoost = boost
            if manager?.applyBoostFast(boost) != true {
                BrightIntoshSettings.shared.brightness = boost
            }
        }
    }

    private func announce(nits: Float, fraction: Float) {
        guard settings.announceWithVoiceOver, NSWorkspace.shared.isVoiceOverEnabled else { return }
        let message = String(localized: "\(Int(nits.rounded())) nits, \(Int((fraction * 100).rounded())) percent")
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    private func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.displayId == id }
    }

    private func builtInDisplayId() -> CGDirectDisplayID? {
        for screen in NSScreen.screens {
            if let id = screen.displayId, CGDisplayIsBuiltin(id) != 0 { return id }
        }
        return nil
    }
}

// MARK: - DisplayServices

private final class DisplayServicesBridge {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private let getFn: GetFn?
    private let setFn: SetFn?

    var available: Bool { getFn != nil && setFn != nil }

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        if let handle = dlopen(path, RTLD_LAZY),
           let get = dlsym(handle, "DisplayServicesGetBrightness"),
           let set = dlsym(handle, "DisplayServicesSetBrightness") {
            getFn = unsafeBitCast(get, to: GetFn.self)
            setFn = unsafeBitCast(set, to: SetFn.self)
        } else {
            getFn = nil
            setFn = nil
        }
    }

    func brightness(_ displayId: CGDirectDisplayID) -> Float? {
        guard let getFn else { return nil }
        var value: Float = 0
        return getFn(displayId, &value) == 0 ? value : nil
    }

    func setBrightness(_ displayId: CGDirectDisplayID, _ value: Float) {
        _ = setFn?(displayId, value)
    }
}
