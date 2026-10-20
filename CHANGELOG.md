# Changelog

All notable changes to this fork. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Brightness keys take over the full range on the built-in display: the normal slider first, then the XDR boost, up to a configurable cap (1600 nits by default).
- Boost step in nits per key press (5 to 200, default 100), a fine-step modifier on Shift + Option, and a choice of 8, 16, 32 or 64 key presses across the normal range.
- Popup with the brightness bar, nits and percentage. It uses Liquid Glass on macOS 26 and a blurred panel on older versions.
- Keys & Popup tab in Settings for the keys, the popup and accessibility.
- Accessibility: follows Reduce Transparency, Increase Contrast and Reduce Motion, optional larger text and border, VoiceOver announcements.
- `BrightnessCurve` model with unit tests (`swift test`).
- GitHub Actions workflow that runs the tests and builds the app.

### Changed

- The boost ceiling is now derived from the display headroom (`referenceEdr^(1/2.2) - 1`) instead of fixed constants, so the full boost matches the 1600 nit panel peak.
- The gamma fade is 0.1 s instead of 0.2 s, and a direct gamma path skips the fade while the key ramp is running.
- The App Sandbox is off in the non-Store build, because taking over the keys needs an event tap.

### Removed

- Upstream funding file, the workflow that notifies the upstream website repository, and the App Store Connect metadata.
