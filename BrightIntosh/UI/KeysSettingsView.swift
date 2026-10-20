//
//  KeysSettingsView.swift
//  BrightIntosh
//
//  Settings tab for the brightness keys, the popup and its accessibility.
//

import SwiftUI

struct KeysSettingsView: View {
    @ObservedObject private var settings = KeysSettings.shared
    @State private var confirmReset = false

    var body: some View {
        Form {
            keysSection
            popupSection
            accessibilitySection

            Section {
                HStack {
                    Spacer()
                    Button("Reset to defaults", role: .destructive) { confirmReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Reset the brightness keys and popup settings?",
            isPresented: $confirmReset
        ) {
            Button("Reset", role: .destructive) { settings.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Keys

    private var keysSection: some View {
        Section(header: Text("Brightness keys").bold()) {
            Toggle("Use the brightness keys for the full range", isOn: $settings.keysEnabled)
            Text("The keys move through the normal range first, then continue into the extra brightness. Needs the Accessibility permission.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Start in the normal range after launch", isOn: $settings.startAtNativeRange)

            LabeledContent("Step above the normal range") {
                HStack {
                    Slider(value: intBinding($settings.boostStepNits), in: 5...200, step: 5)
                        .frame(maxWidth: 220)
                    Text("\(settings.boostStepNits) nits")
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
            }
            Text("Nits added per key press above the normal range. Lower values give finer control.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Key presses across the normal range", selection: $settings.nativeSteps) {
                ForEach(KeysSettings.Limits.nativeStepChoices, id: \.self) { Text("\($0)").tag($0) }
            }

            Picker("Shift + Option makes steps smaller by", selection: $settings.fineDivisor) {
                ForEach(KeysSettings.Limits.fineDivisorChoices, id: \.self) { Text("\($0)×").tag($0) }
            }

            LabeledContent("Maximum brightness") {
                HStack {
                    Slider(value: intBinding($settings.maxNits), in: 600...1600, step: 50)
                        .frame(maxWidth: 220)
                    Text("\(settings.maxNits) nits")
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
            }

            LabeledContent("Smoothing") {
                HStack {
                    Slider(value: intBinding($settings.easeMilliseconds), in: 0...200, step: 10)
                        .frame(maxWidth: 220)
                    Text(settings.easeMilliseconds == 0 ? String(localized: "Off") : "\(settings.easeMilliseconds) ms")
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
            }
            Text("Nits are estimates from the display model, not measurements.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Popup

    private var popupSection: some View {
        Section(header: Text("Popup").bold()) {
            Toggle("Show the popup", isOn: $settings.hudEnabled)

            Group {
                Picker("Size", selection: $settings.hudSize) {
                    ForEach(HUDSize.allCases) { Text($0.title).tag($0) }
                }
                Picker("Position", selection: $settings.hudPosition) {
                    ForEach(HUDPosition.allCases) { Text($0.title).tag($0) }
                }
                Picker("Style", selection: $settings.hudStyle) {
                    ForEach(HUDStyle.allCases) { Text($0.title).tag($0) }
                }

                LabeledContent("Glass tint") {
                    HStack {
                        Slider(value: $settings.hudTint, in: KeysSettings.Limits.tint)
                            .frame(maxWidth: 220)
                        Text("\(Int((settings.hudTint * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    }
                }
                .disabled(settings.hudStyle == .solid)

                LabeledContent("Show for") {
                    HStack {
                        Slider(value: $settings.hudDuration, in: KeysSettings.Limits.duration, step: 0.5)
                            .frame(maxWidth: 220)
                        Text(String(format: "%.1f s", settings.hudDuration))
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    }
                }

                Toggle("Show the icon", isOn: $settings.showIcon)
                Toggle("Show the nits", isOn: $settings.showNits)
                Toggle("Show the bar", isOn: $settings.showBar)
                Toggle("Show the percentage", isOn: $settings.showPercent)

                HStack {
                    Spacer()
                    Button("Preview popup") { BrightnessKeys.shared.previewHUD() }
                }
            }
            .disabled(!settings.hudEnabled)
        }
    }

    // MARK: Accessibility

    private var accessibilitySection: some View {
        Section(header: Text("Accessibility").bold()) {
            Toggle("Follow Reduce Transparency and Increase Contrast", isOn: $settings.followSystemTransparency)
            Text("Uses a solid popup with a border when either is on in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Follow Reduce Motion", isOn: $settings.followSystemMotion)
            Text("Turns off smoothing and the popup fade when Reduce Motion is on.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Larger, bolder text", isOn: $settings.largeText)
            Toggle("Always show a border around the popup", isOn: $settings.highContrastBorder)
            Toggle("Announce brightness with VoiceOver", isOn: $settings.announceWithVoiceOver)
        }
    }

    // MARK: Helpers

    private func intBinding(_ source: Binding<Int>) -> Binding<Double> {
        Binding(
            get: { Double(source.wrappedValue) },
            set: { source.wrappedValue = Int($0.rounded()) }
        )
    }
}
