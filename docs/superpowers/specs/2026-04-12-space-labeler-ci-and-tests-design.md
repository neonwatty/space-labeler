# SpaceLabeler — Repository Setup, Test Suite, and CI Design

**Date:** 2026-04-12
**Status:** Approved via brainstorming
**Scope:** Create the GitHub repository for SpaceLabeler, add an initial test suite,
and configure GitHub Actions CI for pull requests.

## Goals

Turn the existing local SpaceLabeler project (a working macOS menu bar app for
naming virtual desktops) into a versioned, tested, CI-gated GitHub repository
that the author can safely build on top of in the future.

## Failure modes being guarded against

The design targets three failure modes with roughly equal weight:

1. **Silent refactoring regression.** A future change to `SpaceStore`,
   `StatusItemController`, or the shared hex color helpers breaks behavior in a
   way the author does not notice during manual testing.
2. **macOS update silently breaks the private SkyLight API.** Apple renames or
   removes `CGSMainConnectionID` / `CGSGetActiveSpace` in a future macOS
   release; the app keeps running but every Space resolves to the same
   placeholder label.
3. **Build breakage after environment drift.** Returning to the project on a
   new machine (or after upgrading Xcode) yields a project that no longer
   compiles, due to Swift/Xcode version mismatch or a stale `project.yml`.

The test and CI surface area is deliberately sized to cover all three without
introducing infrastructure disproportionate to a ~500 LOC personal tool.

## Out of scope (non-goals)

- Pre-commit and pre-push hooks. CI is the only quality gate.
- UI tests (`XCUITest`). Menu bar tests against `NSStatusBar` are too flaky on
  headless CI runners.
- Code coverage reporting (Codecov, xccov dashboards).
- Artifact upload of the built `.app` from CI.
- Release workflow, versioning automation, or GitHub Releases publication.
- Homebrew tap / formula / other distribution channels.
- A third macOS matrix row beyond `macos-13` and `macos-latest`.
- A `Makefile` or build wrapper script.
- Splitting lint into a separate CI job from build/test.

## Deferred (future work, not this session)

- Customizable keyboard shortcut for opening the popover.
- A "reset all labels" button in the popover's preferences area.
- Proper multi-display handling (per-display Space ID namespacing).
- A custom app icon.

Each of the above becomes a follow-up GitHub issue after the repository exists,
not part of the current work.

---

## 1. Repository basics

### Identity

- **Name:** `space-labeler`
- **Owner:** `neonwatty`
- **Visibility:** Public
- **License:** MIT (added as `LICENSE` in the repo root)

### `.gitignore`

```gitignore
.DS_Store
DerivedData/
build/
*.xcodeproj
*.xcuserstate
xcuserdata/
```

The generated `SpaceLabeler.xcodeproj` is intentionally not committed. The
source of truth is `project.yml`; every clone regenerates the project fresh
via `xcodegen generate`. This avoids hand-edit drift between the spec and the
generated project and eliminates a common source of merge conflicts.

### README updates

The existing `README.md` is expanded to cover:

1. **Requirements** — macOS 13+, Xcode 15+, XcodeGen.
2. **Install** — clone, `xcodegen generate`, build in Xcode or via `xcodebuild`,
   then copy the built `.app` to `~/Applications/SpaceLabeler.app` for Spotlight
   discoverability.
3. **First launch** — explanation that the app registers itself as a login item
   on first launch via `SMAppService`, so it survives reboots.
4. **Development** — regeneration command, test command, lint command.
5. **Private API note** — one-paragraph explanation of `SkyLight.swift` and the
   degraded fallback if the symbols ever disappear.

### Initial commit contents

Everything currently in `/Users/jeremywatt/Desktop/SpaceLabeler/` plus every
new file described in sections 2–4 below, committed as a single "Initial
commit" on the default branch `main`.

---

## 2. Launch-at-login and install location

Two small changes, added during brainstorming because the author discovered
there was no way to relaunch the app after quitting from the popover.

### Piece A — register as a login item

Add one line to `AppDelegate.applicationDidFinishLaunching`:

```swift
try? SMAppService.mainApp.register()
```

This is the modern (macOS 13+) equivalent of the old LaunchAgent plist dance.
On first launch, macOS surfaces a System Settings notification where the user
approves the login item; after that, the app starts automatically on every
login. No entitlements, no helper target, no plist.

The `try?` is deliberate: if registration fails for any reason, the app still
runs normally — the user just has to relaunch manually after reboots. Failure
to register a login item should never prevent the app from starting.

### Piece B — install location

The README documents copying the built `.app` to `~/Applications/`, which is
the standard user-owned install location (no admin privileges required, unlike
`/Applications/`). Once there, Spotlight, Finder, and the Dock can all find it.

The install is a one-line shell command documented in the README; no installer
or build script automates it. Keeping it manual is simpler and makes the
author's workflow explicit.

---

## 3. Test target and test cases

### Framework choice

**XCTest**, not Swift Testing. Swift Testing's `#expect` / `@Test` syntax is
nicer but requires Xcode 16 / macOS 14+, which would break the `macos-13`
matrix row. XCTest is universally available and sufficient for the test shapes
needed here.

### Target structure

A second target is added to `project.yml`:

```yaml
SpaceLabelerTests:
  type: bundle.unit-test
  platform: macOS
  sources:
    - path: Tests/SpaceLabelerTests
  dependencies:
    - target: SpaceLabeler
```

Tests live in `Tests/SpaceLabelerTests/`. The scheme `SpaceLabeler` runs
both the app build and the test suite via `xcodebuild test`.

### Test files

#### `SpaceStoreTests.swift` (failure mode 1)

Uses an isolated `UserDefaults(suiteName:)` per test so the test suite never
pollutes the real app's preferences. `setUp` creates a fresh suite; `tearDown`
removes it.

- `test_labelForUnknownID_autoAssignsAndPersists` — calling `label(for:)` on
  an unknown Space ID auto-assigns a "Space N" name, a palette color, and
  persists to UserDefaults immediately.
- `test_update_persistsAcrossInstances` — create a store, update a label,
  create a second store pointed at the same suite, confirm the label round-
  trips identically.
- `test_autoAssign_rotatesPaletteDeterministically` — request labels for six
  different unknown IDs; assert each auto-assigned color matches the palette
  in the expected rotation order.
- `test_load_handlesCorruptedDefaults` — plant non-JSON bytes under
  `SpaceLabels.v1`; create a store; assert it comes up with an empty labels
  dictionary rather than crashing.

#### `HexColorTests.swift` (failure mode 1)

- `test_validHex_parsesCorrectly` — `"#FF6B6B"`, `"4ECDC4"` (no `#`), and
  mixed-case variants all parse to the expected RGB components within a small
  floating-point tolerance.
- `test_invalidHex_returnsNil` — wrong length, non-hex characters, empty
  string, and `nil`-equivalent inputs all return `nil` without crashing.
- `test_bothExtensions_agree` — for a fixed set of valid hex inputs,
  `NSColor(hex:)` and `Color(hex:)` produce equivalent RGB components. This
  test exists specifically because the two extensions are duplicated across
  `StatusItemController.swift` and `EditorPopover.swift`; the test pins them
  together so a future fix to one cannot silently diverge from the other.

#### `SkyLightSmokeTests.swift` (failure mode 2)

- `test_currentSpaceID_returnsNonNil` — calls `SkyLight.currentSpaceID()` and
  asserts the result is a non-nil `UInt64`. On a CI runner there may be only
  one Space, but the `dlsym` resolution path and the underlying function call
  must succeed. If Apple renames or removes either symbol in a future macOS,
  this test fails loudly on the `macos-latest` matrix row the first time the
  Xcode/macOS image is rolled forward.

### What is explicitly not tested

`StatusItemController`, `EditorPopover`, `AppDelegate`, `SpaceMonitor`, and
`SpaceLabelerApp` are AppKit/SwiftUI glue. Unit-testing them requires either
a real `NSApplication` or extensive Apple-API mocking. The cost-to-value
ratio is poor at this project size. Failure mode 3 (build breakage) already
catches most glue regressions via the `xcodebuild build` step; the pure-
logic test suite catches the rest.

---

## 4. GitHub Actions CI workflow

### File

`.github/workflows/ci.yml`

### Triggers

```yaml
on:
  pull_request:
  push:
    branches: [main]
```

### Concurrency

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

Pushing twice in quick succession on the same PR cancels the earlier run and
starts over on the latest commit, avoiding wasted runner minutes on stale code.

### Job structure

One job, `build-and-test`, running under a matrix over two macOS versions:

```yaml
jobs:
  build-and-test:
    strategy:
      fail-fast: false
      matrix:
        os: [macos-13, macos-latest]
    runs-on: ${{ matrix.os }}
```

`fail-fast: false` is deliberate: a failure on one matrix row should not hide
the result on the other. If `macos-latest` breaks while `macos-13` stays
green, that is the exact signal that Apple changed something relevant in a
newer macOS, and we want to see both results.

### Steps

1. `actions/checkout@v4` — standard checkout.
2. `brew install xcodegen swift-format` — install both tools fresh each run.
   No Homebrew caching initially; brew takes ~60s cold on GitHub's runners,
   which is within the session time budget. Caching is a follow-up optimization.
3. `xcodegen generate` — regenerate `SpaceLabeler.xcodeproj` from `project.yml`.
   Serves double duty as a validity check on `project.yml` itself.
4. `swift-format lint --recursive Sources Tests` — non-strict lint. Style
   errors fail the build; warnings do not. Config lives in `.swift-format` at
   repo root.
5. `xcodebuild build -project SpaceLabeler.xcodeproj -scheme SpaceLabeler -configuration Debug -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO`
   — compile the app. The code-sign overrides are mandatory on GitHub runners,
   which have no signing keys.
6. `xcodebuild test` — same flags, `test` action. Runs the three test files
   from Section 3. Incremental on top of the build step.

Lint runs before build deliberately. Style errors fail in seconds; build and
test are the expensive steps. Failing fast on trivial issues is free throughput.

### `.swift-format` config

Stored at repo root:

```json
{
    "version": 1,
    "lineLength": 120,
    "indentation": { "spaces": 4 },
    "respectsExistingLineBreaks": true,
    "lineBreakBeforeControlFlowKeywords": false
}
```

Permissive defaults: 120-character lines, 4-space indent, don't rewrite
existing line breaks. This matches the style the source already uses and
avoids churning every file on the first run.

### Runtime budget

Approximate per matrix row:

| Step | Time |
|---|---|
| checkout | 5s |
| brew install | 60s |
| xcodegen | 2s |
| swift-format | 2s |
| xcodebuild build | 60s |
| xcodebuild test | 30s |
| **Per row** | **~160s** |

Two rows run in parallel, so wall-clock PR latency is ~3 minutes.

### Failure-mode coverage mapping

| Step | Fails when... | Failure mode |
|---|---|---|
| `xcodegen generate` | `project.yml` invalid | 1 (refactor) |
| `swift-format lint` | Style regressed | 1 (refactor) |
| `xcodebuild build` | Sources do not compile on target macOS | 3 (build) |
| `SpaceStoreTests` | Persistence logic regressed | 1 (refactor) |
| `HexColorTests` | Color parsing drifted between extensions | 1 (refactor) |
| `SkyLightSmokeTests` | Private API symbols no longer resolve | 2 (macOS break) |

All three failure modes have at least one guarding step.

---

## 5. Success criteria

The work is complete when:

1. `/Users/jeremywatt/Desktop/SpaceLabeler/` is a git repository with an
   initial commit on `main` containing all sources, tests, CI config, README,
   LICENSE, and spec.
2. A public GitHub repository `neonwatty/space-labeler` exists, with `main`
   pushed to it.
3. `xcodegen generate && xcodebuild test` passes locally on the author's
   machine with zero failing tests.
4. The `SMAppService.mainApp.register()` call is present in `AppDelegate.swift`
   and the README documents the `~/Applications/` install step.
5. On the first PR against this repository, the CI workflow runs on both
   `macos-13` and `macos-latest`, and both matrix rows pass.
6. Opening a trivial second PR that deliberately breaks one test confirms
   the CI workflow correctly blocks the merge.

Step 6 is an optional end-to-end validation the author can run manually.
