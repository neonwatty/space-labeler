# SpaceLabeler

A minimal macOS menu bar app that lets you name and color-code your virtual desktops (Spaces).

Since macOS doesn't natively let you name your Spaces — and `TotalSpaces2` was killed by Apple's SIP hardening — SpaceLabeler fills a small but annoying gap. It puts a colored dot and a label in your menu bar that updates whenever you switch Spaces, and lets you rename and recolor each one from a popover.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Install

```sh
git clone https://github.com/neonwatty/space-labeler.git
cd space-labeler
xcodegen generate
xcodebuild build \
  -project SpaceLabeler.xcodeproj \
  -scheme SpaceLabeler \
  -configuration Debug \
  -destination 'platform=macOS'

mkdir -p ~/Applications
cp -R ~/Library/Developer/Xcode/DerivedData/SpaceLabeler-*/Build/Products/Debug/SpaceLabeler.app ~/Applications/
open ~/Applications/SpaceLabeler.app
```

On first launch, macOS will prompt you to approve SpaceLabeler as a login item. Once approved, it launches automatically on every login.

If you ever need to relaunch it manually, hit `Cmd+Space` and type "Space Labeler".

## Usage

Look at your menu bar — you'll see a colored dot and the current Space's name (for example, `● Space 1`). Switch Spaces with `Ctrl+←` / `Ctrl+→` and watch the label update. Click the item to open a popover where you can rename or recolor the current Space.

Labels and colors persist across reboots in `UserDefaults` under the key `SpaceLabels.v1`.

## Development

```sh
# Regenerate the Xcode project after editing project.yml
xcodegen generate

# Build
xcodebuild build \
  -project SpaceLabeler.xcodeproj \
  -scheme SpaceLabeler \
  -configuration Debug \
  -destination 'platform=macOS'

# Run the test suite
xcodebuild test \
  -project SpaceLabeler.xcodeproj \
  -scheme SpaceLabeler \
  -destination 'platform=macOS'

# Lint
swift-format lint --recursive Sources Tests
```

The Xcode project file (`SpaceLabeler.xcodeproj`) is gitignored — the source of truth is `project.yml`. Always run `xcodegen generate` after cloning or after editing `project.yml`.

## Notes on the private API

`Sources/SkyLight.swift` resolves two undocumented CoreGraphics symbols at runtime via `dlsym`:

- `CGSMainConnectionID`
- `CGSGetActiveSpace`

These have been stable since roughly macOS 10.11 but are not part of Apple's public API contract. If Apple ever removes them, `SkyLight.currentSpaceID()` returns `nil` and the app gracefully degrades to showing a single "Space" label rather than crashing. The test suite includes a smoke test (`SkyLightSmokeTests`) that fails loudly in CI if the symbols can no longer be resolved on a new macOS version.

App Sandbox and Hardened Runtime are disabled because private symbol lookup is incompatible with the sandbox. This app is intentionally not distributable via the Mac App Store.

## License

MIT. See `LICENSE`.
