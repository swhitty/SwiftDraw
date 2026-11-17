# AGENTS.md

Guidance for coding agents working in this repository.

## Layout

- `DOM/` — `SwiftDrawDOM`: XML/SVG parser producing DOM types. Tests in `DOM/Tests`.
- `SwiftDraw/` — the library: DOM → `LayerTree` → renderers (`Renderer/`: CoreGraphics, Swift code generation, SF Symbols), plus SwiftUI/UIKit/AppKit API. Tests in `SwiftDraw/Tests`.
- `CommandLine/` — the `swiftdrawcli` executable (SVG → PNG/PDF/JPEG/Swift/SF Symbol).
- `Samples.bundle/` — sample SVGs covering supported features; used for rendering comparisons.
- `Tools/swiftdraw-diff/` — dev-only package that compares SwiftDraw's rendering with WebKit and resvg (see below). Not part of the main package.
- `Tools/webkit-render/` — dev-only SVG → PNG renderer using WebKit, run by `swiftdraw-diff`.

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

Unit tests don't catch most visual regressions. For any change under `SwiftDraw/Sources` or `DOM/Sources` that can affect rendered output, run `swiftdraw-diff`. It renders `Samples.bundle` with SwiftDraw at `main` and with your working copy, scores both against WebKit (Safari's engine) and, with `--resvg`, against [resvg](https://github.com/linebender/resvg), and reports what changed. It needs macOS 26 with a logged-in GUI session (for WebKit).

Neither reference is the truth. WebKit renders SVG as an `<img>`, which lacks some SVG 2 and CSS features (CSS filter functions, markers on all shapes, context paint, `mix-blend-mode`) and offsets middle- and end-anchored text. resvg supports more of SVG but has gaps of its own (for example `color(display-p3 …)`). A second reference shows where WebKit falls short, so pass `--resvg` when resvg is installed (`brew install resvg`).

From the repo root:

```bash
swift build -c release -q --package-path Tools/swiftdraw-diff
```

```bash
Tools/swiftdraw-diff/.build/release/swiftdraw-diff compare --base main --resvg Samples.bundle
```

swiftdraw-diff runs three renderers and diffs their PNGs:

- `webkit-render` (`Tools/webkit-render`, built on first use) renders each SVG and decides its size: the browser's natural size, clamped to `--max` and rounded to whole points. Every renderer draws at that size.
- `swiftdrawcli`, built from this repo for each revision. The working copy is rebuilt on every run, so uncommitted changes are always included; a commit's build is cached by SHA in `~/Library/Caches/swiftdraw-diff`, so the first compare against a new base takes about a minute and later ones reuse it.
- `resvg` from `PATH`, with SwiftDraw's fallback fonts (Times, Helvetica, Courier) and CSS's 16px default font size so text is comparable.

`--swiftdraw-path`, `--webkit-render-path` and `--resvg-path` use a given binary instead. WebKit, resvg and committed SwiftDraw renders are cached too; pass `--no-cache` to render everything.

To score one revision without comparing, drop `compare`: `swiftdraw-diff Samples.bundle --resvg` scores the working copy, `--head 0.30.0` a tag or branch.

A directory is searched recursively, and each file is named by its path inside it (`text/text-anchor/simple-case`), as are its outputs. So the whole [resvg test suite](https://github.com/linebender/resvg/tree/main/crates/resvg/tests/tests) is one run: `swiftdraw-diff <resvg>/crates/resvg/tests/tests --resvg`. To score against the suite's own PNGs instead, pass `--resvg-png sibling --scale 2` (they are 300×300, and WebKit sizes the 200×200 viewBox-only tests at 150×150 points). Add `--resvg` as well to render the files whose PNG is missing or a different size with the resvg CLI.

### Reading the result

- Exit code `1` means at least one file **regressed**: it moved further from a reference by more than `--tolerance` percentage points (default 0.5) without moving closer to the other, or it stopped rendering. Exit `0` means no regressions; `2` means the tool failed.
- The summary lists **Regressed**, **Mixed**, **Improved**, **No second reference** and **Changed** files. Each shows `base% → head%` and the change against WebKit and, with `--resvg`, against resvg. Unchanged files are only counted.
- **Mixed** means closer to one reference and further from the other, such as fixing something WebKit gets wrong. It does not fail the run; check those files by eye.
- **No second reference** means further from a reference while the other could not be used for that file (resvg failed, or its `--resvg-png` image is missing or the wrong size). Without it a fix for a WebKit bug looks like a regression, so it does not fail the run; check those files by eye.
- **Text is judged by resvg.** With `--resvg`, a file containing `<text>` is categorised by its resvg score alone, and where all three renderers differ its verdict is **SwiftDraw bug** rather than unclear. WebKit's `<img>` path shifts middle- and end-anchored text by a few units, while Chrome, resvg and SwiftDraw agree. Its WebKit score is still shown, marked `webkit*` in compare and `*` in report; `compare.json` and `scores.json` record `textReference` and, per file, `text` (and `judgedBy` in compare). Without resvg, text is judged by WebKit as before.
- With `--resvg`, each file also gets a verdict, shown as `base → head` when it changes. Two images count as the same below `--match` percent (default 1).
  - **pass**: SwiftDraw matches both references.
  - **pass, WebKit differs**: SwiftDraw matches resvg, and WebKit is the odd one out.
  - **pass, resvg differs**: SwiftDraw matches WebKit, and resvg is the odd one out. Often a feature that WebKit's `<img>` path and SwiftDraw both lack.
  - **SwiftDraw bug**: the references agree, and SwiftDraw matches neither. For text, also when all three differ.
  - **unclear**: all three differ (never for text).
  - compare also prints how many files have each verdict at base and at head.
- Judge by the change between base and head, not the absolute score. Many samples are already imperfect (e.g. `display`, `use`, `mask-composite`); a file staying at a high score is not a regression.
- Text is compared with WebKit's font smoothing off (`-webkit-font-smoothing: antialiased`), because SwiftDraw fills glyph outlines and macOS smoothing makes WebKit's glyphs heavier. Pass `--font-smoothing` to compare against WebKit's default, as browsers show it. Text samples still keep a few percent from glyph positioning; judge them by eye at `--scale 3`.
- A **Redrawn** list means WebKit first drew an image blank (a timing glitch under load) and it was scored from a later draw. That's informational. An image that stays blank after the retries is scored as blank, so a real blank render still shows up as a regression.
- Ignore `Warning: <…> is not supported` lines; they come from SwiftDraw's logging.

### Keeping it cheap

- Read the terminal summary first; it is usually enough.
- To see what changed, view only the PNGs for the files the summary lists, in `Tools/swiftdraw-diff/.build/compare/report/`. The renders are `base/<name>.png`, `head/<name>.png`, `webkit/<name>.png` and `resvg/<name>.png`, and the original is `svg/<name>.svg`. Diffs are in `diff/`: `<name>.change.png` shows base → head, and `<name>.webkit.png` and `<name>.resvg.png` show head against each reference.
- Read `compare.json` (or `scores.json` without `compare`) only if you need numbers the summary doesn't show.
- Don't pass `--html` and don't read `index.html`: it embeds every image (tens of MB) and is meant for people.

### Reviewing a pull request

Fetch it without checking it out, then compare from the merge-base so changes merged to `main` since the PR branched aren't reported against it:

```bash
git fetch origin main pull/123/head:pr/123
```

```bash
Tools/swiftdraw-diff/.build/release/swiftdraw-diff compare --base "$(git merge-base origin/main pr/123)" --head pr/123 --resvg Samples.bundle
```

If the PR adds samples, run it again on the PR's copy at `Tools/swiftdraw-diff/.build/compare/head-src/Samples.bundle`.

## Samples

When adding support for an SVG feature or fixing a rendering bug, add a small focused SVG to `Samples.bundle` that exercises it. That is what lets `swiftdraw-diff` catch future regressions.
