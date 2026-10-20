# BrightIntosh with brightness keys

This is a fork of [BrightIntosh](https://github.com/niklasr22/BrightIntosh) by Niklas Rousset. It lets the brightness keys on a MacBook Pro continue past the normal maximum into the extra range of the XDR display, and shows a popup with the brightness in nits and percent.

The brightness boost itself comes from BrightIntosh: an HDR overlay switches the display into its extended range, and a gamma table lifts SDR content into it. This fork adds the key handling, the popup and the settings around it. It is not affiliated with the upstream project.

## What changed from BrightIntosh

- The brightness keys run on one scale in nits. The first presses use the normal macOS slider. Once it reaches the maximum, each press raises the boost, up to a cap you choose (1600 nits by default).
- Key presses are smooth. The key listener runs on its own thread, and a display-link ramp writes the system brightness and the boost every frame.
- A square popup shows the bar, the nits and the percentage. On macOS 26 it uses Liquid Glass. Older versions get a blurred panel.
- A Keys & Popup tab in Settings controls the step size, the maximum brightness, smoothing, and how the popup looks.
- Accessibility options: the popup follows Reduce Transparency, Increase Contrast and Reduce Motion, can use larger text and a border, and can announce changes with VoiceOver.
- The nits and step logic lives in `BrightnessCurve.swift` and has unit tests.

## Requirements

- A MacBook Pro with a Liquid Retina XDR display. The supported model identifiers are the ones listed in `supportedDevices` in `BrightIntosh/Constants.swift`.
- macOS 14.6 or later. The Liquid Glass popup needs macOS 26.
- Accessibility permission, so the app can take over the brightness keys.

I have only tested this on a MacBook Pro with an M5 chip (Mac17,2). Other models should behave the same, but I have not checked.

## Install

There are no binary releases yet, so you build it yourself. You need Xcode with the macOS 26 SDK.

```bash
git clone https://github.com/Kernel-Hunter/BrightIntosh.git
cd BrightIntosh
xcodebuild -project BrightIntosh.xcodeproj -scheme BrightIntosh -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

The app ends up in `build/Build/Products/Release/BrightIntosh.app`. Sign it with a stable identity before you run it, for example your own development certificate:

```bash
codesign --force --deep -s "Your Certificate Name" \
  --entitlements BrightIntosh/BrightIntosh.entitlements build/Build/Products/Release/BrightIntosh.app
```

Sign with the same identity every time. macOS ties the Accessibility permission to the signature, so an ad hoc signature loses the permission on every rebuild.

On first launch, grant Accessibility access in System Settings, under Privacy & Security. If BrightIntosh is already listed but the keys do nothing, remove it with the minus button, add it again and switch it on.

## Using it

Press the brightness keys as usual. Hold Shift and Option for smaller steps. Settings has a Keys & Popup tab, and its Preview button shows the popup without pressing a key.

The default boost step is 100 nits per press. Lower it for finer control, for example 10 or 20 nits.

## How accurate are the nits?

They are estimates. No public macOS API reports luminance, so the app models it:

- The panel peak is assumed to be 1600 nits.
- SDR white at the full slider is the peak divided by the display's HDR headroom constant, about 600 nits on M3 and newer.
- Below that, nits scale linearly with the slider.
- Above it, the gamma factor scales the encoded signal, and light output is assumed to grow with the factor raised to 2.2.

I have not checked these assumptions with a colorimeter. If you have one, measurements are welcome in an issue.

1600 nits is the peak for small bright areas. The panel cannot hold that on a full white screen, and macOS may dim the display on its own when it gets hot.

## Limitations

- The app calls a private macOS API (`DisplayServices`) and runs without the App Sandbox, so it cannot ship on the Mac App Store. The Store target inherited from BrightIntosh does not include the key handling.
- BrightIntosh and [f.lux](https://justgetflux.com) will likely not work together.
- HDR video clips while the boost is active.
- There is no warranty. The boost goes through the normal display pipeline, but running a display at peak brightness for long periods is your call.

## Development

```bash
swift test
```

runs the unit tests for the brightness model. The app itself builds with `BrightIntosh.xcodeproj`. Read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request.

## License

GPL-3.0, the same as BrightIntosh. The original copyright notices stay in the files they came from. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
