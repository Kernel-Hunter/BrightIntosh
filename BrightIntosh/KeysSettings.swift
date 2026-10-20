//
//  KeysSettings.swift
//  BrightIntosh
//
//  User settings for the brightness keys and the popup. Stored in the same
//  UserDefaults suite as BrightIntoshSettings, under the "keys." prefix.
//

import Foundation
import Combine

enum HUDPosition: String, CaseIterable, Identifiable {
    case bottomCenter, center, topCenter, topRight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bottomCenter: return String(localized: "Bottom center")
        case .center: return String(localized: "Center")
        case .topCenter: return String(localized: "Top center")
        case .topRight: return String(localized: "Top right")
        }
    }
}

enum HUDSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return String(localized: "Small")
        case .medium: return String(localized: "Medium")
        case .large: return String(localized: "Large")
        }
    }
    var scale: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.3
        }
    }
}

enum HUDStyle: String, CaseIterable, Identifiable {
    case glassClear, glassRegular, solid
    var id: String { rawValue }
    var title: String {
        switch self {
        case .glassClear: return String(localized: "Clear glass")
        case .glassRegular: return String(localized: "Frosted glass")
        case .solid: return String(localized: "Solid")
        }
    }
}

@MainActor
final class KeysSettings: ObservableObject {
    static let shared = KeysSettings()

    enum Limits {
        static let boostStepNits = 5...200
        static let maxNits = 600...1600
        static let tint = 0.0...0.6
        static let duration = 0.5...5.0
        static let easeMilliseconds = 0...200
        static let nativeStepChoices = [8, 16, 32, 64]
        static let fineDivisorChoices = [2, 4, 5, 10]
    }

    enum Default {
        static let keysEnabled = true
        static let startAtNativeRange = true
        static let maxNits = 1600
        static let boostStepNits = 100
        static let nativeSteps = 16
        static let fineDivisor = 4
        static let easeMilliseconds = 50
        static let hudEnabled = true
        static let hudSize = HUDSize.medium
        static let hudPosition = HUDPosition.bottomCenter
        static let hudStyle = HUDStyle.glassClear
        static let hudTint = 0.18
        static let hudDuration = 1.5
        static let showIcon = true
        static let showNits = true
        static let showBar = true
        static let showPercent = true
        static let followSystemTransparency = true
        static let followSystemMotion = true
        static let largeText = false
        static let highContrastBorder = false
        static let announceWithVoiceOver = true
    }

    private let defaults = BrightIntoshSettings.defaults
    private let prefix = "keys."

    // MARK: Keys

    @Published var keysEnabled: Bool { didSet { save(keysEnabled, "enabled") } }
    @Published var startAtNativeRange: Bool { didSet { save(startAtNativeRange, "startAtNativeRange") } }
    @Published var maxNits: Int { didSet { maxNits = clamp(maxNits, Limits.maxNits); save(maxNits, "maxNits") } }
    @Published var boostStepNits: Int { didSet { boostStepNits = clamp(boostStepNits, Limits.boostStepNits); save(boostStepNits, "boostStepNits") } }
    @Published var nativeSteps: Int { didSet { save(nativeSteps, "nativeSteps") } }
    @Published var fineDivisor: Int { didSet { save(fineDivisor, "fineDivisor") } }
    @Published var easeMilliseconds: Int { didSet { easeMilliseconds = clamp(easeMilliseconds, Limits.easeMilliseconds); save(easeMilliseconds, "easeMilliseconds") } }

    // MARK: Popup

    @Published var hudEnabled: Bool { didSet { save(hudEnabled, "hudEnabled") } }
    @Published var hudSize: HUDSize { didSet { save(hudSize.rawValue, "hudSize") } }
    @Published var hudPosition: HUDPosition { didSet { save(hudPosition.rawValue, "hudPosition") } }
    @Published var hudStyle: HUDStyle { didSet { save(hudStyle.rawValue, "hudStyle") } }
    @Published var hudTint: Double { didSet { hudTint = clamp(hudTint, Limits.tint); save(hudTint, "hudTint") } }
    @Published var hudDuration: Double { didSet { hudDuration = clamp(hudDuration, Limits.duration); save(hudDuration, "hudDuration") } }
    @Published var showIcon: Bool { didSet { save(showIcon, "showIcon") } }
    @Published var showNits: Bool { didSet { save(showNits, "showNits") } }
    @Published var showBar: Bool { didSet { save(showBar, "showBar") } }
    @Published var showPercent: Bool { didSet { save(showPercent, "showPercent") } }

    // MARK: Accessibility

    @Published var followSystemTransparency: Bool { didSet { save(followSystemTransparency, "followSystemTransparency") } }
    @Published var followSystemMotion: Bool { didSet { save(followSystemMotion, "followSystemMotion") } }
    @Published var largeText: Bool { didSet { save(largeText, "largeText") } }
    @Published var highContrastBorder: Bool { didSet { save(highContrastBorder, "highContrastBorder") } }
    @Published var announceWithVoiceOver: Bool { didSet { save(announceWithVoiceOver, "announceWithVoiceOver") } }

    private init() {
        let d = BrightIntoshSettings.defaults
        func read<T>(_ key: String, _ fallback: T) -> T { d.object(forKey: "keys." + key) as? T ?? fallback }
        func readEnum<E: RawRepresentable>(_ key: String, _ fallback: E) -> E where E.RawValue == String {
            (d.string(forKey: "keys." + key)).flatMap(E.init(rawValue:)) ?? fallback
        }
        func bounded<T: Comparable>(_ value: T, _ range: ClosedRange<T>) -> T {
            min(max(value, range.lowerBound), range.upperBound)
        }

        keysEnabled = read("enabled", Default.keysEnabled)
        startAtNativeRange = read("startAtNativeRange", Default.startAtNativeRange)
        maxNits = bounded(read("maxNits", Default.maxNits), Limits.maxNits)
        boostStepNits = bounded(read("boostStepNits", Default.boostStepNits), Limits.boostStepNits)
        nativeSteps = read("nativeSteps", Default.nativeSteps)
        fineDivisor = read("fineDivisor", Default.fineDivisor)
        easeMilliseconds = bounded(read("easeMilliseconds", Default.easeMilliseconds), Limits.easeMilliseconds)

        hudEnabled = read("hudEnabled", Default.hudEnabled)
        hudSize = readEnum("hudSize", Default.hudSize)
        hudPosition = readEnum("hudPosition", Default.hudPosition)
        hudStyle = readEnum("hudStyle", Default.hudStyle)
        hudTint = bounded(read("hudTint", Default.hudTint), Limits.tint)
        hudDuration = bounded(read("hudDuration", Default.hudDuration), Limits.duration)
        showIcon = read("showIcon", Default.showIcon)
        showNits = read("showNits", Default.showNits)
        showBar = read("showBar", Default.showBar)
        showPercent = read("showPercent", Default.showPercent)

        followSystemTransparency = read("followSystemTransparency", Default.followSystemTransparency)
        followSystemMotion = read("followSystemMotion", Default.followSystemMotion)
        largeText = read("largeText", Default.largeText)
        highContrastBorder = read("highContrastBorder", Default.highContrastBorder)
        announceWithVoiceOver = read("announceWithVoiceOver", Default.announceWithVoiceOver)
    }

    func resetToDefaults() {
        keysEnabled = Default.keysEnabled
        startAtNativeRange = Default.startAtNativeRange
        maxNits = Default.maxNits
        boostStepNits = Default.boostStepNits
        nativeSteps = Default.nativeSteps
        fineDivisor = Default.fineDivisor
        easeMilliseconds = Default.easeMilliseconds
        hudEnabled = Default.hudEnabled
        hudSize = Default.hudSize
        hudPosition = Default.hudPosition
        hudStyle = Default.hudStyle
        hudTint = Default.hudTint
        hudDuration = Default.hudDuration
        showIcon = Default.showIcon
        showNits = Default.showNits
        showBar = Default.showBar
        showPercent = Default.showPercent
        followSystemTransparency = Default.followSystemTransparency
        followSystemMotion = Default.followSystemMotion
        largeText = Default.largeText
        highContrastBorder = Default.highContrastBorder
        announceWithVoiceOver = Default.announceWithVoiceOver
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: prefix + key)
    }

    private func clamp<T: Comparable>(_ value: T, _ range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
