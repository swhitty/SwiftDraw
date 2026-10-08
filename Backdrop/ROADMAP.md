# Roadmap — what this fork adds to SwiftDraw 0.29.0

Each item is one cloud session, one branch, one PR (rules in [CLAUDE.md](../CLAUDE.md)). Items in the same wave
can run in parallel; later waves build on earlier ones. **Corpus** is how many of Backdrop's 372-file FreeSVG test
set the gap rejects today (one file can hit several). Status is maintained by the integrator only.

The gap catalogue behind this list was measured against 0.29.0 by reading the source and rendering; file:line
references below are into 0.29.0. The fork starts from upstream `main` at `cf234e7` (0.29.0 plus comma-separated
`viewBox` and SVG 2 `href` on `<use>`), so those two are already done.

## Wave 1 — parallel

### SD1 — `stroke-dasharray` and `stroke-dashoffset` · corpus 44 · status: PR #2, review fixes requested
Parsed into the DOM (`Parser.XML.Element.swift:244`) and carried in builder state, never drawn: dashes render
solid. Add a `RendererCommand` (e.g. `.setLineDash(phase:lengths:)`), emit it from the CommandGenerator, execute it
in CoreGraphics (`setLineDash`) and CGText. Spec details to honour: odd-length lists repeat to even, negative
values invalidate the attribute (render solid), all-zero lists render solid, `none`, CSS `style=` form, inheritance
from groups, percentages relative to the viewport diagonal.

### SD2 — `feGaussianBlur` rendered · corpus 99 · status: PR #5, review fixes requested
The one filter primitive SwiftDraw parses is never applied: the only consumer of `layer.filters` is a stderr
warning (`LayerTree.CommandGenerator.swift:75`, `:558`) and `hideUnsupportedFilters` is a no-op. Inkscape uses it
for every soft shadow and glow, so those draw as hard-edged blobs. Render a filtered layer into an offscreen
bitmap sized to the **filter region** (`filterUnits` default `objectBoundingBox`, region −10 % / −10 % / 120 % /
120 %; `userSpaceOnUse`), blur with `stdDeviation` (one or two values) converted through the current transform
to device pixels, and composite it back. CoreGraphics side: Core Image or Accelerate/vImage. Design the offscreen
step as a general "filter layer" command so SD12 can add primitives without redesign. CGText: generate equivalent
code or degrade with a comment. Keep the unsupported-filter path for primitives not yet implemented.

### SD3 — reference cycles never crash · status: PR #1, review fixes requested
`<g id="a"><use xlink:href="#a"/></g>` recurses with no cycle check (`LayerTree.Builder.Layer.swift:43-59`):
SIGSEGV. Detect cycles and cap depth for `<use>`, and for every `href` chain (gradients, patterns) — a cycle
drops the reference, never the process.

### SD4 — tolerant parsing: a bad value drops the attribute, not the document · status: PR #3, review fixes requested
Today each of these makes the **whole document** render nothing: `hsl()`/`hsla()`; capitalised colour keywords
and CSS named colours beyond SVG 1.1 (`rebeccapurple`); `inherit`; `clip-path`/`mask`/`filter="none"`;
`transform="none"` or with units (`translate(10px,10px)`, `rotate(45deg)`); empty values (`fill=""`);
`!important`; opacity outside 0…1 or non-numeric (clamp / ignore); non-numeric
`stroke-width`/`font-size`; enum attributes with unknown values (`display="inline-block"`, `stroke-linecap="none"`,
`dominant-baseline="text-top"`); SVG 2 plain `href=` on `<image>` and on every other referencing element
(`<use>` already has it upstream: `Parser.XML.Use.swift`, follow that pattern). Also fix 4- and 8-digit hex colours, which parse to a **different colour** (`#ff0000ff`
renders blue). Parser files: `DOM/Sources/Parser.XML.*.swift`.

### SD5 — patterns complete · corpus 14+ · status: PR #4, review fixes requested
`<pattern>` `x`/`y`, `patternUnits`, `patternContentUnits`, `patternTransform` and `viewBox` are dropped, so tiles
land misplaced; a pattern without `width`/`height` is fatal (it should simply paint nothing, per spec). Inkscape
writes most patterns as `<pattern xlink:href="#base" patternTransform="…"/>`: implement `href` inheritance of
attributes **and** content.

## Wave 2 — after wave 1 merges

### SD6 — gradients to spec · status: todo
`xlink:href` inheritance follows one hop, same kind only, stops only (`LayerTree.Builder.swift:372-412`). Implement
multi-hop and cross-kind inheritance of stops **and** attributes (coordinates, `gradientUnits`,
`gradientTransform`, `spreadMethod`), `spreadMethod` `reflect`/`repeat`, a single stop painting a solid colour, zero
stops painting `none`, and `fx`/`fy` focal points if missing.

### SD7 — `display` and `visibility` · status: todo
`display="none"` is ignored and the element draws — and the early return that should hide it skips transform,
clip, mask and opacity, so hidden geometry reappears misplaced and unclipped. `visibility="hidden"`/`collapse` is
not parsed (and a child may set `visible` again). Elements in an editor namespace (`<inkscape:foo>`) must drop
their subtree; today their children are re-parented onto the nearest ancestor and drawn.

### SD8 — clip paths and masks to spec · status: todo
`clipPathUnits="objectBoundingBox"` is parsed and never used by CoreGraphics (geometry read as user units: clipped
to nearly nothing); same check for `maskUnits`/`maskContentUnits`. A `<clipPath>` containing a `<use>` or `<text>`
degenerates to no clip at all. `clip-path` on a `<clipPath>` itself.

### SD9 — `preserveAspectRatio` · status: todo
Not present in the codebase: the viewBox always maps as `none`, so a non-square drawing in a differently-shaped
frame is skewed. Root `<svg>`, nested `<svg>`, `<image>`; all nine alignments × `meet`/`slice`.

### SD10 — CSS cascade · status: todo
`transform`, `mask` and `clip-rule` written in CSS (`style=` or a class) are never applied. One bad declaration
(`var(--x)` is enough) discards the entire `<style>` sheet. Selectors beyond bare type, `.class` and `#id` never
match: add descendant, child, compound, attribute selectors and `:first-child`, with specificity and source order.

### SD15 — an invalid element is skipped, not the document · status: todo
Found reviewing SD4: a missing mandatory attribute (`<path>` without `d`, `<rect>` without `width`, `<image>`
without `href`) or an unparseable optional geometry value (`x=""`) still throws out of `parseGraphicsElements`, which
has no catch, so the **whole document** vanishes — `parseError`/`skipInvalidElements` exist and are dead code. Skip
the offending element (and only it), keep its siblings; make `skipInvalidElements` real and the default.

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
(percentages against the nearest viewport).

### SD14 — text · status: todo
`<tspan>` drawn only as a fallback and at (0,0) without its own x/y: implement positioning (`x`, `y`, `dx`, `dy`
inheritance) and mixed runs; parse `font-weight`/`font-style`; draw stroked text.

## Integrator's log

- 2026-10-08 — Wave 1 reviewed (five PRs, CI green): SD5 mergeable, the other four "merge after fix"; fix lists sent
  back to each session. Trial merge of all five builds and passes on macOS; one trivial conflict (SD4 × SD1 in
  `parsePresentationAttributes`), resolved by the integrator at merge time — sessions need not rebase. SD15 added.

- 2026-10-08 — Fork created from upstream 0.29.0; this roadmap written from Backdrop's measured gap catalogue.
