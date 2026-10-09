# CLAUDE.md — Misoservices/SwiftDraw (Backdrop's fork)

This is a fork of [swhitty/SwiftDraw](https://github.com/swhitty/SwiftDraw) (zlib licence) kept by Misoservices
for **Backdrop / MisoScape**, an Apple-platform app that draws user-placed SVG motifs through SwiftDraw's
CoreGraphics renderer. The fork exists to render the SVG that real editors (Inkscape, Illustrator, Figma) emit
and that SwiftDraw 0.29.0 drops or draws wrong. The work list is **[Backdrop/ROADMAP.md](Backdrop/ROADMAP.md)**;
every session takes exactly one item from it.

## Build and test

- `swift build --build-tests && swift test --skip-build` — works on Linux (Swift 6.0–6.3) and macOS.
- **Also run the tests optimized:** `swift test -c release -Xswiftc -enable-testing`. Apps ship Release builds,
  and SD12's floods were transparent under `-O` while every Debug job passed; CI's `xcode_release` job runs it.
- **Cloud sessions run on Linux, where CoreGraphics does not exist.** Everything under
  `#if canImport(CoreGraphics)` is neither compiled nor tested there. The fork's GitHub Actions (`build.yml`)
  runs macOS 26 / Xcode 26.6, four Linux toolchains and Windows on every push: **push your branch early and
  treat a green macOS job as the only proof that CoreGraphics code compiles and passes.** If you cannot read the
  CI result from the session, say so in the PR description rather than claiming it passed.
- If `swift` is missing, install a Linux toolchain (swiftly, or the swift.org tarball for 6.2+) and report the
  exact commands you used in the PR so the environment's setup script can adopt them.

## How the code is laid out (read before changing anything)

- `DOM/Sources/` — XML → `DOM.*` model (`Parser.XML.*.swift`). Platform-independent.
- `SwiftDraw/Sources/LayerTree/` — DOM → `LayerTree` (`LayerTree.Builder*.swift`), then
  `LayerTree.CommandGenerator` turns layers into a flat stream of `RendererCommand`s
  (`SwiftDraw/Sources/Renderer/Renderer.swift`). Platform-independent and the best place to test.
- Renderers execute commands: `Renderer.CoreGraphics.swift` (the one Backdrop uses), `Renderer.CGText*.swift`
  (Swift code generation), `Renderer.SFSymbol*.swift`, `Renderer.SVG.swift`, `Renderer.LayerTree.swift`.
  **A new `RendererCommand` case must be handled by every renderer**: implement it for CoreGraphics and CGText;
  elsewhere implement it or degrade deliberately (and say which in the PR).
- Tests: `SwiftDraw/Tests/` (XCTest; `Renderer/MockRenderer.swift` records command streams — assert on those so
  the test runs on Linux), `DOM/Tests/`. `Samples.bundle/` holds sample SVGs.

## Rules

1. **One roadmap item per branch and PR.** Branch `sd<N>-<slug>` (e.g. `sd1-dasharray`) from `main`; open the PR
   against `Misoservices/SwiftDraw` `main`, never against upstream. Keep the diff to the item: no reformatting, no
   drive-by refactors, so each PR can later be offered upstream on its own.
2. **Never fail the whole document for one bad attribute.** SwiftDraw today throws on many legal-but-unexpected
   values and the entire drawing vanishes. The fork's direction: drop the attribute (use the spec default), keep
   the document. Never introduce a new throw path for input an editor could plausibly produce.
3. **Follow the SVG 1.1 spec (SVG 2 where editors already emit it), and cite the section** you implemented in
   the PR description. When the spec and browsers disagree, match Chrome/Safari and say so.
4. **Tests are the deliverable.** Every behaviour gets a test asserting on the DOM, the LayerTree or the
   `MockRenderer` command stream (Linux-runnable), plus a CoreGraphics test where pixels matter (macOS CI).
   Add a small sample SVG to `Samples.bundle/` for each visible feature.
5. Match the surrounding code: 4-space indentation, upstream's naming and file layout, the existing licence
   header on new files. Add new enum cases and `switch` arms at the end to keep parallel branches mergeable.
6. **Do not edit `Backdrop/ROADMAP.md`** — several sessions run in parallel and it would conflict. Put status,
   decisions, spec citations and anything left undone in the PR description; the integrator updates the roadmap.
7. zlib licence clause 2: altered versions must be plainly marked. Keep the notice at the top of `README.md`;
   never remove or alter the licence header of an existing file.
8. Performance matters: Backdrop renders motifs while the user drags sliders. Anything that allocates an offscreen
   bitmap (filters) must size it to the filter region in device pixels, not the whole canvas.
