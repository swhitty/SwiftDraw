# AGENTS.md

Guidance for coding agents working in this repository.

## Layout

- `DOM/` — `SwiftDrawDOM`: XML/SVG parser producing DOM types. Tests in `DOM/Tests`.
- `SwiftDraw/` — the library: DOM → `LayerTree` → renderers (`Renderer/`: CoreGraphics, Swift code generation, SF Symbols), plus SwiftUI/UIKit/AppKit API. Tests in `SwiftDraw/Tests`.
- `CommandLine/` — the `swiftdrawcli` executable (SVG → PNG/PDF/JPEG/Swift/SF Symbol).
- `Samples.bundle/` — sample SVGs covering supported features; used for rendering comparisons.
- `Tools/swiftdraw-diff/` — dev-only package that compares SwiftDraw's rendering with WebKit (see below). Not part of the main package.
- `Tools/webkit-render/` — dev-only package that renders SVGs to PNGs with WebKit, the reference renderer (see Renderers). Doesn't depend on SwiftDraw.

## Build and test

```bash
swift build
swift test
```

The library is cross-platform: CI builds and tests on macOS, Linux (Swift 6.2 and later), Windows and Android. Code in `SwiftDraw/Sources` that uses Apple frameworks must be guarded, usually with `#if canImport(CoreGraphics)`. Passing on macOS is not enough: Linux and Windows have no CoreGraphics, so `SVG` is a stub there and AppKit does not import Foundation for you. Before opening a pull request that touches sources or tests, run the tests on Linux too:

```bash
./container-run-tests.sh
```

It runs `swift test` in a `swift:6.4` container (Apple's `container` tool, as CI's `linux_swift_6_4` job) and passes extra arguments on, e.g. `--filter SVGHostileTests`. Tests that must run everywhere should go through `DOM.SVG.parse` and `LayerTree` (with `LayerTreeProvider`) rather than `SVG(data:)`.

### Locking

Guard shared mutable state with `Mutex` (`DOM/Sources/Mutex.swift`, `package` in SwiftDrawDOM), not `NSLock`, `os_unfair_lock`, `DispatchQueue` or `@unchecked Sendable` with a hand-rolled lock. Keep the state inside the mutex (`Mutex(State())` and `withLock { $0… }`) so it can't be read without holding the lock, and a class holding only a `Mutex` and immutable properties can be plain `Sendable`. It backports `Synchronization.Mutex` on Darwin and is `Synchronization.Mutex` elsewhere, so on Linux a file that calls `withLock` must import `Synchronization` itself:

```swift
#if !canImport(Darwin)
import Synchronization
#endif
```

### Writing tests

Write all new tests with Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), including tests brought in from other branches or pull requests. Follow the existing suites: a `struct`, `@Test` functions named for the behaviour without a `test` prefix, and `@Test(arguments:)` instead of looping over inputs. Some older suites still use XCTest; when adding to one, a new Swift Testing suite is preferred over more XCTest cases.

## Checking rendering changes

Unit tests don't catch most visual regressions. For any change under `SwiftDraw/Sources` or `DOM/Sources` that can affect rendered output, run `swiftdraw-diff`, which renders `Samples.bundle` with SwiftDraw at `main` and with your working copy, scores both against WebKit (Safari's engine) and reports what changed. It needs macOS with a logged-in GUI session.

From the repo root:

```bash
swift build -c release -q --package-path Tools/swiftdraw-diff
```

```bash
Tools/swiftdraw-diff/.build/release/swiftdraw-diff compare --base main Samples.bundle
```

The first run builds SwiftDraw at the base revision (about a minute); later runs reuse it.

### Reading the result

- Exit code `1` means at least one file **regressed**: further from WebKit by more than `--tolerance` percentage points (default 0.5), or it stopped parsing. Exit `0` means no regressions.
- The summary lists only **Regressed**, **Improved** and **Changed** files (Changed = pixels differ but the score stayed within tolerance), each as `base% → head%` and the change. Unchanged files are only counted.
- Judge by the change between base and head, not the absolute score. Many samples are already imperfect (e.g. `display`, `use`, `mask-composite`); a file staying at a high score is not a regression.
- Text is compared with WebKit's font smoothing off (`-webkit-font-smoothing: antialiased`), because SwiftDraw fills glyph outlines and macOS smoothing makes WebKit's glyphs heavier. Pass `--font-smoothing` to compare against WebKit's default, as browsers show it. Text samples still keep a few percent from glyph positioning; judge them by eye at `--scale 4`.
- A **Redrawn** list means an image first drew blank in the scoring page (a WebKit timing glitch under load) and was scored from a later draw. That's informational. An image that stays blank after the retries is scored as blank, so a real blank render still shows up as a regression.
- Ignore `Warning: <…> is not supported` lines; they come from SwiftDraw's logging.

### Keeping it cheap

- Read the terminal summary first; it is usually enough.
- To see what changed, view only the PNGs for the files the summary lists, in `Tools/swiftdraw-diff/.build/compare/report/`: `base/<name>.png`, `head/<name>.png` and the original `svg/<name>.svg`.
- Read `compare.json` only if you need numbers the summary doesn't show.
- Don't pass `--html` and don't read `index.html`: it embeds every image (tens of MB) and is meant for people.

### Renderers

`swiftdraw-diff` compares PNGs from standalone renderers, each taking an SVG and a size in points and writing an opaque sRGB PNG of `round(W×scale) × round(H×scale)` pixels:

- `swiftdrawcli`, built at the commit being compared.
- `Tools/webkit-render`, the WebKit (Safari) reference. It draws the SVG as an `<img>` onto a white canvas, retrying draws that come out blank, with font smoothing off unless `--font-smoothing`. Batch mode (`--jobs jobs.json --out <dir>`) keeps one web view for all files and writes `<dir>/manifest.json`; `--version` prints the WebKit version. It needs a logged-in GUI session.
- `resvg`.

```bash
swift build -c release -q --package-path Tools/webkit-render
```

```bash
Tools/webkit-render/.build/release/webkit-render in.svg out.png --size 64x64 --scale 2
```

### Reviewing a pull request

Fetch it without checking it out, then compare from the merge-base so changes merged to `main` since the PR branched aren't reported against it:

```bash
git fetch origin main pull/123/head:pr/123
```

```bash
Tools/swiftdraw-diff/.build/release/swiftdraw-diff compare --base "$(git merge-base origin/main pr/123)" --head pr/123 Samples.bundle
```

If the PR adds samples, run it again on the PR's copy at `Tools/swiftdraw-diff/.build/compare/head-src/Samples.bundle`.

## Samples

When adding support for an SVG feature or fixing a rendering bug, add a small focused SVG to `Samples.bundle` that exercises it. That is what lets `swiftdraw-diff` catch future regressions.
