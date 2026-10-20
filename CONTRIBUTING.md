# Contributing

Issues and pull requests are welcome.

## Before you open an issue

- If the problem is in the brightness boost itself (the HDR overlay or the gamma table), it probably comes from upstream. Check [BrightIntosh's issues](https://github.com/niklasr22/BrightIntosh/issues) first.
- If it is about the brightness keys, the popup, the settings or the nits, open an issue here.
- Include your Mac model identifier (About This Mac, then System Report), your macOS version, and what you pressed and saw. A short screen recording helps for popup problems.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep the change small and focused. Match the style of the code around it.
3. Run `swift test`. If you change `BrightnessCurve.swift`, add or update tests.
4. Build the app with `xcodebuild` (see the README) and try the change on a real display. The key handling and the popup cannot be tested without one.
5. Describe what changed and why in the pull request, and say which Mac and macOS version you tested on.

Add new Swift files to both app targets in `BrightIntosh.xcodeproj`, the regular one and the Store edition.

## Licensing

By contributing you agree that your work is released under the GPL-3.0, the same license as the rest of the project.

## Conduct

Be respectful. Harassment and discrimination are not tolerated, and maintainers may remove comments or ban people who engage in them.
