import Foundation

extension Runner {

    /// Writes a page that shows each original SVG (rendered live by whichever
    /// browser opens the page) beside SwiftDraw's PNG, plus a JS canvas diff.
    func writeEyeball(_ results: [Result], scale: CGFloat, hideBelow: Double, to url: URL) throws {
        struct Row: Encodable { var name: String; var w: Int; var h: Int; var status: String }
        let rows = results.map { Row(name: $0.name, w: Int($0.size.width), h: Int($0.size.height), status: $0.status) }
        let json = String(data: try JSONEncoder().encode(rows), encoding: .utf8)!
        // Embed every asset as a data: URI so index.html is fully self-contained:
        // it opens from file:// in any browser (Safari included), and data: images
        // never taint a canvas, so the pixel diff works with no server.
        let dir = url.deletingLastPathComponent()
        var assets: [String: [String: String]] = [:]
        for r in results {
            var entry: [String: String] = [:]
            if let svg = try? Data(contentsOf: dir.appendingPathComponent("svg/\(r.name).svg")) {
                entry["svg"] = "data:image/svg+xml;base64," + svg.base64EncodedString()
            }
            if let png = try? Data(contentsOf: dir.appendingPathComponent("images/\(r.name).swiftdraw.png")) {
                entry["png"] = "data:image/png;base64," + png.base64EncodedString()
            }
            assets[r.name] = entry
        }
        // JSONEncoder escapes "/" as "\/", so the JSON can never close the <script> tag.
        let assetsJSON = String(data: try JSONEncoder().encode(assets), encoding: .utf8)!

        let html = eyeballTemplate
            .replacingOccurrences(of: "__STYLE__", with: sharedStyle)
            .replacingOccurrences(of: "__SHARED_JS__", with: sharedScript)
            .replacingOccurrences(of: "__ROWS__", with: json)
            .replacingOccurrences(of: "__SCALE__", with: "\(scale)")
            .replacingOccurrences(of: "__HIDE__", with: "\(hideBelow)")
            .replacingOccurrences(of: "__ASSETS__", with: assetsJSON) // last: it's large
        try html.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("data.js")) // from older runs
    }
}

private let eyeballTemplate = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SwiftDraw Eyeball</title>
<style>
__STYLE__</style>
</head>
<body>
<header>
  <h1>SwiftDraw Eyeball</h1>
  <input id="q" type="search" placeholder="Find file…  ( / )" autocomplete="off" spellcheck="false" style="width:14em">
  <label>Zoom <input id="zoom" type="range" min="0.5" max="4" step="0.25" value="1"><span id="zoomv">1×</span></label>
  <label>Sort <select id="sort"><option value="name">name</option><option value="score">diff (worst first)</option></select></label>
  <label>Hide below <input id="hide" type="number" min="0" max="100" step="0.5" style="width:4em">%</label>
  <span class="meta" id="count"></span>
  <label><input id="checker" type="checkbox"> checkerboard</label>
  <span class="meta" id="ua"></span>
  <span id="note"></span>
</header>
<main id="list"></main>
<script>window.ASSETS = __ASSETS__;</script>
<script>
const ROWS = __ROWS__;
const DEFAULT_HIDE = __HIDE__; // percent; rows scoring below this are hidden
const SCALE = __SCALE__;      // SwiftDraw PNGs are rendered at this pixel scale
const BLUR = Math.round(SCALE); // box-blur radius in pixels, absorbs anti-aliasing
const THRESHOLD = 32;          // max per-channel delta (0-255) after blur

const ASSETS = window.ASSETS || {};
// Prefer the embedded data: URIs (work from file://); fall back to the files.
function svgSrc(r) { return ASSETS[r.name]?.svg ?? `svg/${encodeURIComponent(r.name)}.svg`; }
function pngSrc(r) { return ASSETS[r.name]?.png ?? `images/${encodeURIComponent(r.name)}.swiftdraw.png`; }

const list = document.getElementById('list');
const note = document.getElementById('note');
document.getElementById('ua').textContent = browserName();

__SHARED_JS__

function rowEl(r) {
  const el = document.createElement('section');
  el.className = 'row';
  el.id = r.name;
  const svg = svgSrc(r);
  const png = pngSrc(r);
  const svgFile = `svg/${encodeURIComponent(r.name)}.svg`;
  const w = r.w, h = r.h;
  const failed = r.status !== 'rendered' && !/match|close|differs|fail/.test(r.status);
  el.innerHTML = `
    <h2><a href="#${r.name}">${r.name}</a> <span class="score">…</span>
        <span class="meta">${w}×${h}${failed ? ' · <span class="err">' + r.status + '</span>' : ''}</span>
        <a class="meta" href="${svgFile}" target="_blank">open svg</a></h2>
    <div class="cells">
      <figure><figcaption>Browser (live SVG)</figcaption><div class="frame"><img class="z" src="${svg}" data-w="${w}" data-h="${h}"></div></figure>
      <figure><figcaption>SwiftDraw (PNG @${SCALE}x)</figcaption><div class="frame">${failed && r.status === 'swiftdraw-nil' ? '<div class="err" style="padding:8px;line-height:1.4">SwiftDraw could not parse</div>' : `<img class="z" src="${png}" data-w="${w}" data-h="${h}">`}</div></figure>
      <figure><figcaption>Diff (red = differs)</figcaption><div class="frame"><canvas class="z diff" data-w="${w}" data-h="${h}"></canvas></div></figure>
      <figure class="flip"><figcaption>Flip (hover / click): SwiftDraw → browser</figcaption><div class="frame"><img class="z a" src="${png}" data-w="${w}" data-h="${h}"><img class="z b" src="${svg}" data-w="${w}" data-h="${h}"></div></figure>
    </div>`;
  el.querySelector('.flip').addEventListener('click', e => e.currentTarget.classList.toggle('on'));
  r.el = el;
  r.score = null;
  return el;
}

async function compare(r) {
  const scoreEl = r.el.querySelector('.score');
  if (r.status === 'swiftdraw-nil' || !r.w) { r.score = 1; scoreEl.textContent = 'n/a'; scoreEl.className = 'score bad'; return; }
  try {
    const pw = Math.round(r.w * SCALE), ph = Math.round(r.h * SCALE);
    const browser = await drawChecked(svgSrc(r), pw, ph, r, 'browser svg');
    const swiftdraw = await drawChecked(pngSrc(r), pw, ph, r, 'swiftdraw png');
    const d = diff(browser, swiftdraw, pw, ph);
    const canvas = r.el.querySelector('canvas.diff');
    canvas.width = pw; canvas.height = ph;
    canvas.getContext('2d').putImageData(d.image, 0, 0);
    r.score = d.score;
    scoreEl.textContent = (d.score * 100).toFixed(2) + '% differs';
    scoreEl.className = 'score ' + scoreClass(d.score);
  } catch (e) {
    scoreEl.textContent = e.name === 'SecurityError' ? 'diff unavailable' : 'error';
    scoreEl.className = 'score meta';
    r.error = e.name + ': ' + e.message;
    if (e.name === 'SecurityError') {
      note.textContent = 'Diff blocked by the browser (canvas tainted). Regenerate the report or serve this folder over http';
    } else {
      scoreEl.title = e.message;
    }
  }
}

const hideInput = document.getElementById('hide');
const searchInput = document.getElementById('q');
const countEl = document.getElementById('count');
hideInput.value = store.get('hide') ?? DEFAULT_HIDE;

// A search shows every matching row, ignoring the hide threshold,
// so any file can be found even if it matches perfectly.
function isVisible(r) {
  const q = searchInput.value.trim().toLowerCase();
  if (q) return r.name.toLowerCase().includes(q);
  const hide = parseFloat(hideInput.value || '0') / 100;
  return !(r.score !== null && r.score < hide);
}

function updateVisibility() {
  let shown = 0, hidden = 0;
  for (const r of ROWS) {
    const v = isVisible(r);
    r.el.style.display = v ? '' : 'none';
    if (v) shown++; else hidden++;
  }
  const pending = ROWS.filter(r => r.score === null).length;
  countEl.textContent = searchInput.value.trim()
    ? `${shown} match${shown === 1 ? '' : 'es'}`
    : `showing ${shown} of ${ROWS.length}` + (hidden ? ` · ${hidden} below ${hideInput.value}%` : '') + (pending ? ` · ${pending} comparing…` : '');
}

function applyFilters() {
  const sort = document.getElementById('sort').value;
  const rows = [...ROWS];
  if (sort === 'score') rows.sort((a, b) => (b.score ?? -1) - (a.score ?? -1));
  for (const r of rows) list.appendChild(r.el);
  updateVisibility();
}

function jumpToFirstMatch() {
  const first = [...list.children].find(el => el.style.display !== 'none');
  if (first) first.scrollIntoView({ block: 'start' });
}

ROWS.forEach(r => list.appendChild(rowEl(r)));
applyZoom();
document.getElementById('zoom').addEventListener('input', applyZoom);
document.getElementById('sort').addEventListener('change', applyFilters);
hideInput.addEventListener('input', () => { store.set('hide', hideInput.value); updateVisibility(); });
searchInput.addEventListener('input', () => { updateVisibility(); window.scrollTo(0, 0); });
searchInput.addEventListener('keydown', e => {
  if (e.key === 'Enter') { e.preventDefault(); jumpToFirstMatch(); }
  if (e.key === 'Escape') { searchInput.value = ''; updateVisibility(); searchInput.blur(); }
});
document.addEventListener('keydown', e => {
  if (e.key === '/' && document.activeElement !== searchInput && !/INPUT|SELECT|TEXTAREA/.test(document.activeElement.tagName)) {
    e.preventDefault(); searchInput.focus(); searchInput.select();
  }
});
document.getElementById('checker').addEventListener('change', e =>
  document.querySelectorAll('.frame').forEach(f => f.classList.toggle('checker', e.target.checked)));

(async () => {
  updateVisibility();
  for (const r of ROWS) { await compare(r); updateVisibility(); }
  applyFilters();
  window.EYEBALL_DONE = true; // polled by the CLI's hidden WKWebView scorer
})();
</script>
</body>
</html>
"""#
