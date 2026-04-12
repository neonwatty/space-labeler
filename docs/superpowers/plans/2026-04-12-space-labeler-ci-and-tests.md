# SpaceLabeler — CI and Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the working local SpaceLabeler macOS menu bar app into a versioned, tested, CI-gated public GitHub repository at `neonwatty/space-labeler`, and add a `SMAppService` login-item registration so the app survives reboots.

**Architecture:** Add one small refactor to make `SpaceStore` testable (inject `UserDefaults`), add a new `SpaceLabelerTests` target with three test files covering pure logic and the private SkyLight API, add repo scaffolding (LICENSE, `.gitignore`, `.swift-format`, README update), add a single-job GitHub Actions workflow with a `macos-13` + `macos-latest` matrix, then `git init`, single initial commit, and `gh repo create`.

**Tech Stack:** Swift 5.9, AppKit, SwiftUI, XCTest, XcodeGen, GitHub Actions, `swift-format`, `gh` CLI, macOS `ServiceManagement` framework.

**Pre-flight:** The author's working directory is `/Users/jeremywatt/Desktop/SpaceLabeler/`. All tasks run from that directory unless otherwise noted. The spec for this work is at `docs/superpowers/specs/2026-04-12-space-labeler-ci-and-tests-design.md`.

---

## File Structure

**Files to create:**

- `Tests/SpaceLabelerTests/SpaceStoreTests.swift` — persistence + auto-assignment + corruption-resilience tests
- `Tests/SpaceLabelerTests/HexColorTests.swift` — hex parsing validity + dual-extension agreement tests
- `Tests/SpaceLabelerTests/SkyLightSmokeTests.swift` — private API symbol-resolution test
- `.gitignore` — excludes `DerivedData`, `*.xcodeproj`, `.DS_Store`, `xcuserdata`
- `LICENSE` — MIT license text
- `.swift-format` — JSON config, permissive defaults (120-char lines, 4-space indent)
- `.github/workflows/ci.yml` — single-job GHA workflow, matrix over `macos-13` + `macos-latest`

**Files to modify:**

- `Sources/SpaceStore.swift` — accept `UserDefaults` injection in `init`
- `Sources/AppDelegate.swift` — register as login item via `SMAppService`
- `project.yml` — add `SpaceLabelerTests` target
- `README.md` — add Requirements / Install / Development / Private API sections

**Files untouched:** `Sources/SpaceLabelerApp.swift`, `Sources/SpaceMonitor.swift`, `Sources/SkyLight.swift`, `Sources/StatusItemController.swift`, `Sources/EditorPopover.swift`.

---

## Task 1: Make `SpaceStore` injectable

**Files:**
- Modify: `Sources/SpaceStore.swift`

Background: the existing `SpaceStore.init()` reads `UserDefaults.standard` directly. To let tests run against an isolated suite (so they never pollute the real app's preferences), we add a `UserDefaults` parameter with a `.standard` default. Call sites don't change.

- [ ] **Step 1: Modify `SpaceStore.swift`**

Change the class body. The old file has these shapes:

```swift
final class SpaceStore: ObservableObject {
    @Published var labels: [UInt64: SpaceLabel] = [:]

    private let labelsKey = "SpaceLabels.v1"
    private let palette = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3", "#C7B8EA", "#FFA07A"]

    init() {
        load()
    }
    // ... rest uses UserDefaults.standard
```

Replace with:

```swift
final class SpaceStore: ObservableObject {
    @Published var labels: [UInt64: SpaceLabel] = [:]

    private let labelsKey = "SpaceLabels.v1"
    private let palette = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3", "#C7B8EA", "#FFA07A"]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }
```

Then in `load()`, replace `UserDefaults.standard` with `self.defaults`:

```swift
    private func load() {
        if let data = defaults.data(forKey: labelsKey),
           let decoded = try? JSONDecoder().decode([String: SpaceLabel].self, from: data) {
            var converted: [UInt64: SpaceLabel] = [:]
            for (key, value) in decoded {
                if let id = UInt64(key) {
                    converted[id] = value
                }
            }
            labels = converted
        }
    }
```

And in `save()`, same substitution:

```swift
    private func save() {
        var stringKeyed: [String: SpaceLabel] = [:]
        for (key, value) in labels {
            stringKeyed[String(key)] = value
        }
        if let data = try? JSONEncoder().encode(stringKeyed) {
            defaults.set(data, forKey: labelsKey)
        }
    }
```

Do not change `AppDelegate.swift` — it calls `SpaceStore()` with no arguments and still compiles because `.standard` is the default.

- [ ] **Step 2: Rebuild to confirm nothing broke**

Run:
```sh
xcodegen generate
xcodebuild build -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **` at the end.

---

## Task 2: Add the `SpaceLabelerTests` target to `project.yml`

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Append the test target to `project.yml`**

The existing `targets:` block has only `SpaceLabeler`. Append a second entry so the full `targets:` block reads:

```yaml
targets:
  SpaceLabeler:
    type: application
    platform: macOS
    sources:
      - path: Sources
    info:
      path: Sources/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: SpaceLabeler
        CFBundleDisplayName: Space Labeler
        CFBundleIdentifier: com.jeremywatt.SpaceLabeler
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        LSMinimumSystemVersion: "13.0"
        NSHumanReadableCopyright: "Copyright © 2026 Jeremy Watt"

  SpaceLabelerTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/SpaceLabelerTests
    dependencies:
      - target: SpaceLabeler
```

- [ ] **Step 2: Create a placeholder test file so `xcodegen` doesn't fail on an empty directory**

Create `Tests/SpaceLabelerTests/_PlaceholderTests.swift` with:

```swift
import XCTest

final class _PlaceholderTests: XCTestCase {
    func test_placeholder() {
        XCTAssertTrue(true)
    }
}
```

This file is deleted at the end of Task 5 once real tests exist.

- [ ] **Step 3: Regenerate the Xcode project**

Run:
```sh
xcodegen generate
```

Expected: `Created project at /Users/jeremywatt/Desktop/SpaceLabeler/SpaceLabeler.xcodeproj`

- [ ] **Step 4: Verify the test target runs**

Run:
```sh
xcodebuild test -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: `Test Suite 'SpaceLabelerTests.xctest' passed` and `** TEST SUCCEEDED **`. If you see `'SpaceLabelerTests' is not available` or similar, the target was not wired correctly — re-check `project.yml` and `xcodegen generate`.

---

## Task 3: Write `SpaceStoreTests.swift`

**Files:**
- Create: `Tests/SpaceLabelerTests/SpaceStoreTests.swift`

- [ ] **Step 1: Write the full test file**

Create `Tests/SpaceLabelerTests/SpaceStoreTests.swift` with:

```swift
import XCTest
@testable import SpaceLabeler

final class SpaceStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SpaceLabelerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_labelForUnknownID_autoAssignsAndPersists() {
        let store = SpaceStore(defaults: defaults)
        let label = store.label(for: 42)

        XCTAssertEqual(label.name, "Space 1")
        XCTAssertFalse(label.colorHex.isEmpty)
        XCTAssertTrue(label.colorHex.hasPrefix("#"))
        XCTAssertNotNil(defaults.data(forKey: "SpaceLabels.v1"))
    }

    func test_update_persistsAcrossInstances() {
        let store1 = SpaceStore(defaults: defaults)
        _ = store1.label(for: 99)
        store1.update(99, SpaceLabel(name: "Code", colorHex: "#4ECDC4"))

        let store2 = SpaceStore(defaults: defaults)
        let loaded = store2.labels[99]

        XCTAssertEqual(loaded?.name, "Code")
        XCTAssertEqual(loaded?.colorHex, "#4ECDC4")
    }

    func test_autoAssign_rotatesPaletteDeterministically() {
        let store = SpaceStore(defaults: defaults)
        let palette = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#95E1D3", "#C7B8EA", "#FFA07A"]

        // autoAssign computes n = labels.count + 1 then picks palette[n % palette.count].
        // Six successive assignments from an empty store yield indices [1,2,3,4,5,0].
        let expectedIndices = [1, 2, 3, 4, 5, 0]

        for (i, expectedIdx) in expectedIndices.enumerated() {
            let label = store.label(for: UInt64(100 + i))
            XCTAssertEqual(label.colorHex, palette[expectedIdx], "iteration \(i)")
        }
    }

    func test_load_handlesCorruptedDefaults() {
        defaults.set(Data([0xFF, 0x00, 0xFF, 0x00]), forKey: "SpaceLabels.v1")

        let store = SpaceStore(defaults: defaults)

        XCTAssertTrue(store.labels.isEmpty, "Store should come up empty when defaults are corrupted, not crash")
    }
}
```

- [ ] **Step 2: Regenerate the project and run the new tests**

Regeneration is required because XcodeGen needs to re-glob `Tests/SpaceLabelerTests/` to pick up the new file. Run:
```sh
xcodegen generate && xcodebuild test -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -configuration Debug -destination 'platform=macOS' -only-testing:SpaceLabelerTests/SpaceStoreTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: All four tests pass. Look for `Test Suite 'SpaceStoreTests' passed` and `** TEST SUCCEEDED **`.

If `test_autoAssign_rotatesPaletteDeterministically` fails, the palette rotation logic in `SpaceStore.autoAssign` may differ from what the test expects. Open `SpaceStore.swift` and trace the `n = labels.count + 1` math to confirm the expected-index sequence.

---

## Task 4: Write `HexColorTests.swift`

**Files:**
- Create: `Tests/SpaceLabelerTests/HexColorTests.swift`

- [ ] **Step 1: Write the full test file**

Create `Tests/SpaceLabelerTests/HexColorTests.swift` with:

```swift
import XCTest
import AppKit
import SwiftUI
@testable import SpaceLabeler

final class HexColorTests: XCTestCase {

    func test_validHex_parsesCorrectly() {
        // "#FF6B6B" = (255, 107, 107)
        let c1 = NSColor(hex: "#FF6B6B")?.usingColorSpace(.sRGB)
        XCTAssertNotNil(c1)
        XCTAssertEqual(c1?.redComponent ?? -1, 255.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c1?.greenComponent ?? -1, 107.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c1?.blueComponent ?? -1, 107.0 / 255.0, accuracy: 0.01)

        XCTAssertNotNil(NSColor(hex: "4ECDC4"), "should parse hex without leading #")
        XCTAssertNotNil(NSColor(hex: "#ff6b6b"), "should accept lowercase")
        XCTAssertNotNil(NSColor(hex: "#Ff6B6b"), "should accept mixed case")
    }

    func test_invalidHex_returnsNil() {
        XCTAssertNil(NSColor(hex: ""))
        XCTAssertNil(NSColor(hex: "#"))
        XCTAssertNil(NSColor(hex: "ABC"))           // too short
        XCTAssertNil(NSColor(hex: "#12345678"))     // too long
        XCTAssertNil(NSColor(hex: "#ZZZZZZ"))       // non-hex chars
        XCTAssertNil(NSColor(hex: "   "))           // whitespace only
    }

    func test_bothExtensions_agree() {
        // NSColor(hex:) (in StatusItemController.swift) and Color(hex:) (in EditorPopover.swift)
        // are duplicated. This test guards against drift between the two implementations.
        let cases = ["#FF6B6B", "#4ECDC4", "#FFE66D", "#000000", "#FFFFFF"]

        for hex in cases {
            guard let ns = NSColor(hex: hex)?.usingColorSpace(.sRGB) else {
                XCTFail("NSColor failed to parse \(hex)")
                continue
            }
            guard let swiftUI = Color(hex: hex) else {
                XCTFail("SwiftUI Color failed to parse \(hex)")
                continue
            }
            guard let bridged = NSColor(swiftUI).usingColorSpace(.sRGB) else {
                XCTFail("Could not bridge SwiftUI Color for \(hex)")
                continue
            }

            XCTAssertEqual(ns.redComponent, bridged.redComponent, accuracy: 0.01, "r mismatch for \(hex)")
            XCTAssertEqual(ns.greenComponent, bridged.greenComponent, accuracy: 0.01, "g mismatch for \(hex)")
            XCTAssertEqual(ns.blueComponent, bridged.blueComponent, accuracy: 0.01, "b mismatch for \(hex)")
        }
    }
}
```

- [ ] **Step 2: Regenerate the project and run the new tests**

Run:
```sh
xcodegen generate && xcodebuild test -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -configuration Debug -destination 'platform=macOS' -only-testing:SpaceLabelerTests/HexColorTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
```

Expected: All three tests pass.

If `test_bothExtensions_agree` fails for `#000000` or `#FFFFFF`, it is almost certainly a color-space mismatch between the two extensions. Check that both use `.sRGB` as their color space (`NSColor.init(srgbRed:...)` and `Color.init(.sRGB, red:...)`).

---

## Task 5: Write `SkyLightSmokeTests.swift` and delete the placeholder

**Files:**
- Create: `Tests/SpaceLabelerTests/SkyLightSmokeTests.swift`
- Delete: `Tests/SpaceLabelerTests/_PlaceholderTests.swift`

- [ ] **Step 1: Write the smoke test file**

Create `Tests/SpaceLabelerTests/SkyLightSmokeTests.swift` with:

```swift
import XCTest
@testable import SpaceLabeler

final class SkyLightSmokeTests: XCTestCase {

    /// If Apple removes or renames CGSMainConnectionID / CGSGetActiveSpace,
    /// `dlsym` resolution fails and `currentSpaceID()` returns nil. This test
    /// fails loudly on the `macos-latest` CI matrix row the first time the
    /// Xcode/runner image is rolled forward to a macOS that broke the private
    /// API. That is the early-warning signal the test exists to produce.
    func test_currentSpaceID_returnsNonNil() {
        let id = SkyLight.currentSpaceID()
        XCTAssertNotNil(
            id,
            "SkyLight private API symbol resolution failed — Apple may have changed CGSGetActiveSpace"
        )
    }
}
```

- [ ] **Step 2: Delete the placeholder file**

Run:
```sh
rm Tests/SpaceLabelerTests/_PlaceholderTests.swift
```

- [ ] **Step 3: Regenerate the project and run the full test suite**

Run:
```sh
xcodegen generate && xcodebuild test -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -30
```

Expected: All eight tests across three test classes pass. Look for:
- `Test Suite 'SpaceStoreTests' passed`
- `Test Suite 'HexColorTests' passed`
- `Test Suite 'SkyLightSmokeTests' passed`
- `** TEST SUCCEEDED **`

If `test_currentSpaceID_returnsNonNil` fails on the local machine (not CI), something is genuinely wrong with `SkyLight.swift` — possibly the `dlopen(nil, RTLD_NOW)` call is not finding the expected symbols. Open `Sources/SkyLight.swift` and verify the symbol names are exactly `CGSMainConnectionID` and `CGSGetActiveSpace`.

---

## Task 6: Add `SMAppService` login-item registration

**Files:**
- Modify: `Sources/AppDelegate.swift`

- [ ] **Step 1: Replace the contents of `Sources/AppDelegate.swift`**

The current file has only `import AppKit` and a simple `applicationDidFinishLaunching`. Replace the whole file with:

```swift
import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: SpaceMonitor!
    private var store: SpaceStore!
    private var statusController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerAsLoginItem()
        monitor = SpaceMonitor()
        store = SpaceStore()
        statusController = StatusItemController(monitor: monitor, store: store)
    }

    /// Register the app to launch automatically at login. The first call on a
    /// given user account surfaces a System Settings prompt; after that it is
    /// silent. `try?` because registration failure should never block startup:
    /// the user can always relaunch manually or toggle the setting in System
    /// Settings → General → Login Items.
    private func registerAsLoginItem() {
        try? SMAppService.mainApp.register()
    }
}
```

- [ ] **Step 2: Build to confirm compilation**

Run:
```sh
xcodebuild build -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

Do not re-launch the app to test `SMAppService` — the first-run approval flow is interactive and can only be validated by the user clicking "Allow" in System Settings, which is out of scope for this plan. Build success alone is the verification.

---

## Task 7: Create `.gitignore`

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Write `.gitignore`**

Create `.gitignore` with:

```gitignore
.DS_Store
DerivedData/
build/
*.xcodeproj
*.xcuserstate
xcuserdata/
```

No verification needed — the file is static.

---

## Task 8: Create `LICENSE`

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Write the MIT license text**

Create `LICENSE` with:

```text
MIT License

Copyright (c) 2026 Jeremy Watt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Task 9: Create `.swift-format` config

**Files:**
- Create: `.swift-format`

- [ ] **Step 1: Write the config**

Create `.swift-format` (JSON format) with:

```json
{
    "version": 1,
    "lineLength": 120,
    "indentation": { "spaces": 4 },
    "respectsExistingLineBreaks": true,
    "lineBreakBeforeControlFlowKeywords": false
}
```

- [ ] **Step 2: Install `swift-format` locally (one-time)**

`swift-format` is only needed locally if you want to run lint manually; CI installs it on every run. If it is not already installed:

```sh
brew install swift-format
```

If `swift-format` is already installed, skip this step.

- [ ] **Step 3: Run lint against the existing sources**

Run:
```sh
swift-format lint --recursive Sources Tests
```

Expected: zero output (no errors). If the linter reports any style errors, fix them in-place by running:

```sh
swift-format format --in-place --recursive Sources Tests
```

and then re-run `swift-format lint --recursive Sources Tests` until it produces zero output. Then re-run the test suite to confirm nothing broke:

```sh
xcodebuild test -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** TEST SUCCEEDED **`.

---

## Task 10: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the contents of `README.md`**

Overwrite the whole file with:

````markdown
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
````

---

## Task 11: Create the GitHub Actions workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the CI workflow**

Create `.github/workflows/ci.yml` with:

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-and-test:
    strategy:
      fail-fast: false
      matrix:
        os: [macos-13, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: brew install xcodegen swift-format

      - name: Generate Xcode project
        run: xcodegen generate

      - name: Lint
        run: swift-format lint --recursive Sources Tests

      - name: Build
        run: |
          xcodebuild build \
            -project SpaceLabeler.xcodeproj \
            -scheme SpaceLabeler \
            -configuration Debug \
            -destination 'platform=macOS' \
            CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

      - name: Test
        run: |
          xcodebuild test \
            -project SpaceLabeler.xcodeproj \
            -scheme SpaceLabeler \
            -configuration Debug \
            -destination 'platform=macOS' \
            CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
```

No local verification is possible for this file — it only runs on GitHub after the repo is pushed.

---

## Task 12: `git init` and initial commit

**Files:**
- Run shell commands only (no file creation/modification in this task)

- [ ] **Step 1: Confirm no Xcode process is writing to the directory**

Close the Xcode app if it is open on this project (Xcode can hold file handles that interfere with git on the first commit):

```sh
osascript -e 'tell application "Xcode" to quit' 2>/dev/null || true
```

- [ ] **Step 2: Initialize the repository**

Run:
```sh
cd /Users/jeremywatt/Desktop/SpaceLabeler
git init -b main
```

Expected: `Initialized empty Git repository in /Users/jeremywatt/Desktop/SpaceLabeler/.git/` and the branch is set to `main` from the start.

- [ ] **Step 3: Confirm `.gitignore` is in effect**

Run:
```sh
git status
```

Expected: `SpaceLabeler.xcodeproj/` should NOT appear in the untracked list. If it does, check `.gitignore` from Task 7 — the line `*.xcodeproj` must be present.

- [ ] **Step 4: Stage all files**

Run:
```sh
git add .
git status
```

Expected: The status shows `Sources/`, `Tests/`, `docs/`, `project.yml`, `README.md`, `LICENSE`, `.gitignore`, `.swift-format`, `.github/workflows/ci.yml` all staged as new files. No `.xcodeproj` directory should be staged.

- [ ] **Step 5: Create the initial commit**

Run:
```sh
git commit -m "$(cat <<'EOF'
Initial commit: SpaceLabeler menu bar app for naming macOS Spaces

A minimal macOS menu bar app that puts a colored dot and a label
in the menu bar showing the name of the current virtual desktop,
with rename/recolor via a popover and persistence across reboots.

Includes XCTest coverage for persistence, hex color parsing, and
SkyLight private-API symbol resolution, plus a GitHub Actions CI
workflow running on a macos-13 + macos-latest matrix.
EOF
)"
```

Expected: `[main (root-commit) <hash>] Initial commit: ...` and a summary showing roughly 20+ files created.

---

## Task 13: Create the GitHub repository and push

**Files:**
- Run shell commands only

- [ ] **Step 1: Confirm `gh` is authenticated**

Run:
```sh
gh auth status
```

Expected: output shows `Logged in to github.com as neonwatty`. If not, run `gh auth login` first and follow the interactive prompts, then retry this step.

- [ ] **Step 2: Create the public repository and push**

Run:
```sh
gh repo create neonwatty/space-labeler \
  --public \
  --description "Minimal macOS menu bar app for naming and color-coding virtual desktops (Spaces)" \
  --source=. \
  --remote=origin \
  --push
```

Expected: `✓ Created repository neonwatty/space-labeler on GitHub` followed by `✓ Pushed commits to https://github.com/neonwatty/space-labeler.git`.

- [ ] **Step 3: Open the repo in the browser to confirm it looks right**

Run:
```sh
gh repo view neonwatty/space-labeler --web
```

Expected: the browser opens to the GitHub page for the new repo. Visually confirm:
- README renders correctly with all sections
- LICENSE file is visible
- `Sources/`, `Tests/`, `docs/`, and `.github/` directories are present
- No `.xcodeproj/` directory is present

- [ ] **Step 4: Verify CI runs**

Watch the Actions tab (either in the browser, or via `gh run list --limit 5`). The `push: branches: [main]` trigger should start a workflow run within ~10 seconds of the push.

Run:
```sh
gh run list --limit 3
```

Expected: at least one recent run for the CI workflow. Wait for it to finish (~3-5 minutes) and confirm with:

```sh
gh run list --limit 1
```

Expected: the most recent run shows `completed  success` for the `CI` workflow on `main`. If either matrix row shows `failure`, inspect with `gh run view <run-id> --log-failed` and fix whatever broke on that macOS version before considering the plan complete.

---

## Success criteria

All of the following must be true for the work to be complete:

1. `/Users/jeremywatt/Desktop/SpaceLabeler/` is a git repository on branch `main` with at least one commit.
2. `https://github.com/neonwatty/space-labeler` exists, is public, and contains the pushed commit.
3. `xcodegen generate && xcodebuild test -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO` passes cleanly on the author's machine, with all eight tests across three test classes reported as passing.
4. `Sources/AppDelegate.swift` contains a call to `SMAppService.mainApp.register()`.
5. `README.md` documents the `~/Applications/` install step.
6. The first CI run on the pushed repository completes with `success` on both `macos-13` and `macos-latest` matrix rows.
