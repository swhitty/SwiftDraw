# Roadmap — what this fork adds to SwiftDraw 0.29.0

Each item is one cloud session, one branch, one PR (rules in [CLAUDE.md](../CLAUDE.md)). Items in the same wave
can run in parallel; later waves build on earlier ones. **Corpus** is how many of Backdrop's 372-file FreeSVG test
set the gap rejects today (one file can hit several). Status is maintained by the integrator only.

The gap catalogue behind this list was measured against 0.29.0 by reading the source and rendering; file:line
references below are into 0.29.0. The fork starts from upstream `main` at `cf234e7` (0.29.0 plus comma-separated
`viewBox` and SVG 2 `href` on `<use>`), so those two are already done.

## Wave 1 — parallel

### SD1 — `stroke-dasharray` and `stroke-dashoffset` · corpus 44 · status: merged (#2)
Parsed into the DOM (`Parser.XML.Element.swift:244`) and carried in builder state, never drawn: dashes render
solid. Add a `RendererCommand` (e.g. `.setLineDash(phase:lengths:)`), emit it from the CommandGenerator, execute it
in CoreGraphics (`setLineDash`) and CGText. Spec details to honour: odd-length lists repeat to even, negative
values invalidate the attribute (render solid), all-zero lists render solid, `none`, CSS `style=` form, inheritance
from groups, percentages relative to the viewport diagonal.

### SD2 — `feGaussianBlur` rendered · corpus 99 · status: merged (#5)
The one filter primitive SwiftDraw parses is never applied: the only consumer of `layer.filters` is a stderr
warning (`LayerTree.CommandGenerator.swift:75`, `:558`) and `hideUnsupportedFilters` is a no-op. Inkscape uses it
for every soft shadow and glow, so those draw as hard-edged blobs. Render a filtered layer into an offscreen
bitmap sized to the **filter region** (`filterUnits` default `objectBoundingBox`, region −10 % / −10 % / 120 % /
120 %; `userSpaceOnUse`), blur with `stdDeviation` (one or two values) converted through the current transform
to device pixels, and composite it back. CoreGraphics side: Core Image or Accelerate/vImage. Design the offscreen
step as a general "filter layer" command so SD12 can add primitives without redesign. CGText: generate equivalent
code or degrade with a comment. Keep the unsupported-filter path for primitives not yet implemented.

### SD3 — reference cycles never crash · status: merged (#1)
`<g id="a"><use xlink:href="#a"/></g>` recurses with no cycle check (`LayerTree.Builder.Layer.swift:43-59`):
SIGSEGV. Detect cycles and cap depth for `<use>`, and for every `href` chain (gradients, patterns) — a cycle
drops the reference, never the process.

### SD4 — tolerant parsing: a bad value drops the attribute, not the document · status: merged (#3)
Today each of these makes the **whole document** render nothing: `hsl()`/`hsla()`; capitalised colour keywords
and CSS named colours beyond SVG 1.1 (`rebeccapurple`); `inherit`; `clip-path`/`mask`/`filter="none"`;
`transform="none"` or with units (`translate(10px,10px)`, `rotate(45deg)`); empty values (`fill=""`);
`!important`; opacity outside 0…1 or non-numeric (clamp / ignore); non-numeric
`stroke-width`/`font-size`; enum attributes with unknown values (`display="inline-block"`, `stroke-linecap="none"`,
`dominant-baseline="text-top"`); SVG 2 plain `href=` on `<image>` and on every other referencing element
(`<use>` already has it upstream: `Parser.XML.Use.swift`, follow that pattern). Also fix 4- and 8-digit hex colours, which parse to a **different colour** (`#ff0000ff`
renders blue). Parser files: `DOM/Sources/Parser.XML.*.swift`.

### SD5 — patterns complete · corpus 14+ · status: merged (#4)
`<pattern>` `x`/`y`, `patternUnits`, `patternContentUnits`, `patternTransform` and `viewBox` are dropped, so tiles
land misplaced; a pattern without `width`/`height` is fatal (it should simply paint nothing, per spec). Inkscape
writes most patterns as `<pattern xlink:href="#base" patternTransform="…"/>`: implement `href` inheritance of
attributes **and** content.

## Wave 2 — parallel

### SD6 — gradients to spec · status: merged (#8)
`xlink:href` inheritance follows one hop, same kind only, stops only (`LayerTree.Builder.swift:372-412`). Implement
multi-hop and cross-kind inheritance of stops **and** attributes (coordinates, `gradientUnits`,
`gradientTransform`, `spreadMethod`), `spreadMethod` `reflect`/`repeat`, a single stop painting a solid colour, zero
stops painting `none`, and `fx`/`fy` focal points if missing.

### SD7 — `display` and `visibility` · status: PR #10, fixes requested
`display="none"` is ignored and the element draws — and the early return that should hide it skips transform,
clip, mask and opacity, so hidden geometry reappears misplaced and unclipped. `visibility="hidden"`/`collapse` is
not parsed (and a child may set `visible` again). Elements in an editor namespace (`<inkscape:foo>`) must drop
their subtree; today their children are re-parented onto the nearest ancestor and drawn.

### SD8 — clip paths and masks to spec · status: PR #11, fixes requested
`clipPathUnits="objectBoundingBox"` is parsed and never used by CoreGraphics (geometry read as user units: clipped
to nearly nothing); same check for `maskUnits`/`maskContentUnits`. A `<clipPath>` containing a `<use>` or `<text>`
degenerates to no clip at all. `clip-path` on a `<clipPath>` itself. `clip-rule` belongs to the shapes inside the
`<clipPath>` (inherited from it, SVG 1.1 §14.3.5), not to the element that references it; SD10 left it on the
referencing element, and its test `testClipRuleFromStyleSheet` and the `.holed` sample pin that interim placement —
move them with it.

### SD9 — `preserveAspectRatio` · status: merged (#7)
Not present in the codebase: the viewBox always maps as `none`, so a non-square drawing in a differently-shaped
frame is skewed. Root `<svg>`, nested `<svg>`, `<image>`; all nine alignments × `meet`/`slice`.

### SD10 — CSS cascade · status: PR #9, third round requested
`transform`, `mask` and `clip-rule` written in CSS (`style=` or a class) are never applied. One bad declaration
(`var(--x)` is enough) discards the entire `<style>` sheet. Selectors beyond bare type, `.class` and `#id` never
match: add descendant, child, compound, attribute selectors and `:first-child`, with specificity and source order.

### SD15 — an invalid element is skipped, not the document · status: merged (#6)
Found reviewing SD4: a missing mandatory attribute (`<path>` without `d`, `<rect>` without `width`, `<image>`
without `href`) or an unparseable optional geometry value (`x=""`) still throws out of `parseGraphicsElements`, which
has no catch, so the **whole document** vanishes — `parseError`/`skipInvalidElements` exist and are dead code. Skip
the offending element (and only it), keep its siblings; make `skipInvalidElements` real and the default.

### SD16 — wave 2 follow-ups · status: todo (after wave 2)
Small defects found reviewing merged items, none blocking. **SD6:** each gradient `href` hop scans `svg.defs`
linearly (`first(where:)`), so N chained gradients cost ~64·N² compares: index ids once in `GradientCache`;
`makePeriods` always includes period 0, so a linear `repeat`/`reflect` far from its vector (fine period, shape
beyond x≈10 000) falls to the average colour — use `floor(lower)...ceil(upper)−1`; `testHrefChainResolvesInsideDeepUse`
passes on the old code (needs a 3-hop chain or 15+ nested uses); the `ReferenceGuard` doc still tells gradient
walks to use it; mixed sRGB/P3 stops are averaged as raw components. **SD9:** a root with its own `clip-path`
skips the `slice` viewport clip (`l.clip.isEmpty`), so the overflow bleeds again — intersect instead; a `none` or
`slice` pattern fit can reach `inf` on a tiny viewBox (no `isFinite` check); CGText never letterboxes `<image>`
(the bitmap size is unknown there) and still references an undeclared `image`;
`testPatternParsesAndInheritsPreserveAspectRatio` does not check the inherited value.

## Wave 3

### SD11 — `<symbol>`, `<marker>`, `<switch>` · status: todo
`<use>` → `<symbol>` renders blank (`<symbol>` is not parsed; honour its `viewBox` and `preserveAspectRatio`).
`<marker>` with `marker-start`/`-mid`/`-end` (arrowheads). `<switch>` renders its first child unconditionally:
evaluate `systemLanguage`, `requiredFeatures`, `requiredExtensions`.

### SD12 — filter primitives beyond blur · status: todo (needs SD2)
`feOffset`, `feFlood`, `feComposite`, `feMerge`, `feBlend`, `feColorMatrix` — enough for the drop-shadow pipelines
editors emit — on SD2's filter-layer design, with `in`/`in2`/`result` wiring and `SourceGraphic`/`SourceAlpha`.

### SD13 — units and percentages on all geometry · status: todo
Non-root lengths ignore units: `width="20%"` becomes 20. Implement %, px, pt, pc, mm, cm, in, em, ex per spec
(percentages against the nearest viewport). Root sizes too: `width`/`height` are stored as `Int` (`DOM.Length`),
so `width="145.11934"` becomes 145, and since SD9 a `viewBox` with the exact size letterboxes by a fraction of a
unit (44 of Backdrop's wishlist drawings move 0.3–5.9 % for this alone); keep root, nested `<svg>` and `<image>`
sizes fractional. With only `width` or only `height` and a `viewBox`, derive the missing side from the viewBox's
aspect ratio: today the viewBox's own height is used, so `width="200" viewBox="0 0 100 50"` is 200×50 where browsers
give 200×100.

### SD14 — text · status: todo
`<tspan>` drawn only as a fallback and at (0,0) without its own x/y: implement positioning (`x`, `y`, `dx`, `dy`
inheritance) and mixed runs; parse `font-weight`/`font-style`; draw stroked text.

## Integrator's log

- 2026-10-08 — SD6 (#8, head 029e35a), SD9 (#7, af85330) and SD15 (#6, 0000ed3) merged after their fix rounds
  (CI 20/20 each, every point of the fix lists done). Integrator resolutions: SD9 × SD6 adjacent test additions in
  `CGRendererTests` (both kept); SD15 × SD6 semantic — SD6 makes a bad `stop-opacity` drop only the attribute, so
  SD15's `badDefinitionsAreDroppedNotTheDocument` now expects that gradient to survive. Main: 412 XCTest + 268
  Swift Testing pass on macOS. Corpus, each PR against main: SD15 0 drawings changed, 1 newly accepted; SD6 4
  changed, all `reflect` (the silver party hat 29 %); SD9 one shipping FreeSVG (0.2 %) and 44 wishlist drawings
  (0.3–5.9 %), all from root sizes stored as `Int` (now in SD13) — spec-correct letterboxing of a fractional
  `viewBox` into a truncated viewport. SD15's fix round first overflowed 512 KB Debug test stacks on 500 nested
  groups (the recursive defs walkers each gained a closure frame); 0000ed3 fixed it. Back to their sessions: SD10
  (third round: SF Symbol class names such as `.hierarchical-0:secondary` now parse as pseudo-classes and vanish
  from the export; its benchmark cannot fail), SD7 (cut from 111c801; `testShapes` changed on a wrong diagnosis —
  `<ns:g>` is a declared SVG prefix; `display` must not apply to `<mask>`), SD8 (`<clipPath transform>` order
  under `objectBoundingBox`, mixed text+shape bbox, reference budget). SD16 collects the non-blocking follow-ups.

- 2026-10-08 — SD2 merged (#5, head 977b7de after its second round; CI 20/20; corpus: only the blurred party hat
  changes). Wave 2 reviewed (four PRs, CI green): all four "merge after fix", fix lists sent back. Trial merge of
  SD2 and wave 2 builds and passes on macOS once one semantic conflict is resolved: SD2 and SD6 each add a private
  `LayerTree.Rect.corners` in `LayerTree.CommandGenerator.swift` (SD6 merges main and keeps SD2's). SD7 and SD8 start.

- 2026-10-08 — SD4 (#3) and SD1 (#2) merged; the SD4 × SD1 conflict resolved by the integrator, plus a follow-up
  (983e027): the SD1 fix had put the dash reset in the radial-gradient *fill* branch and left the radial-gradient
  *stroke* without one (CGText leak). Main: 303 XCTest + 247 Swift Testing pass on macOS. Corpus with SD2 included
  (trial): 0 regressions on every bank. SD2 back for a second round (mixed text+shape filter region drops the text;
  region clip lost under rotation; per-axis kernel clamp).

- 2026-10-08 — SD3 merged (#1, head 136287e; CI 20/20; corpus 0 changes, draw time +0.3 %). Follow-ups noted, not
  blocking: the ancestor check re-walks the target per `<use>` (fine on the corpus); the 20,000 budget also counts
  pattern fills and masks, so a document with more pattern-filled shapes than that loses the extra fills.
- 2026-10-08 — SD5 merged (#4, head 11f2810 after review fixes; CI 20/20; corpus 0 regressions).

- 2026-10-08 — Wave 1 reviewed (five PRs, CI green): SD5 mergeable, the other four "merge after fix"; fix lists sent
  back to each session. Trial merge of all five builds and passes on macOS; one trivial conflict (SD4 × SD1 in
  `parsePresentationAttributes`), resolved by the integrator at merge time — sessions need not rebase. SD15 added.

- 2026-10-08 — Fork created from upstream 0.29.0; this roadmap written from Backdrop's measured gap catalogue.
