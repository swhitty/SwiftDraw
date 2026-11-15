import Foundation

extension Comparer {

    /// Writes a self-contained page showing WebKit / base / head for every SVG.
    /// Its JavaScript scores base and head against the browser's own rendering
    /// and diffs base against head; the CLI reads those results back.
    func writeComparePage(base: [RenderedFile], head: [RenderedFile], baseLabel: String, headLabel: String, dir: URL, to url: URL) throws {
        struct Row: Encodable { var name: String; var w: Int; var h: Int; var baseStatus: String; var headStatus: String }
        let baseByName = Dictionary(base.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        var rows: [Row] = []
        var assets: [String: [String: String]] = [:]
        for h in head {
            let b = baseByName[h.name]
            // Lay out at the head size; fall back to base if head failed.
            let w = h.width > 0 ? h.width : (b?.width ?? 0)
            let hh = h.height > 0 ? h.height : (b?.height ?? 0)
            rows.append(Row(name: h.name, w: w, h: hh, baseStatus: b?.status ?? "missing", headStatus: h.status))
            var entry: [String: String] = [:]
            entry["svg"] = dataURI(dir.appendingPathComponent("svg/\(h.name).svg"), type: "image/svg+xml")
            entry["base"] = dataURI(dir.appendingPathComponent("base/\(h.name).png"), type: "image/png")
            entry["head"] = dataURI(dir.appendingPathComponent("head/\(h.name).png"), type: "image/png")
            assets[h.name] = entry
        }
        let html = compareTemplate
            .replacingOccurrences(of: "__STYLE__", with: sharedStyle)
            .replacingOccurrences(of: "__SHARED_JS__", with: sharedScript)
            .replacingOccurrences(of: "__ROWS__", with: String(data: try JSONEncoder().encode(rows), encoding: .utf8)!)
            .replacingOccurrences(of: "__SCALE__", with: "\(options.scale)")
            .replacingOccurrences(of: "__TOLERANCE__", with: "\(options.tolerance)")
            .replacingOccurrences(of: "__BASE_LABEL__", with: htmlEscape(baseLabel))
            .replacingOccurrences(of: "__HEAD_LABEL__", with: htmlEscape(headLabel))
            // JSONEncoder escapes "/" as "\/", so this can never close the <script> tag. Last: it's large.
            .replacingOccurrences(of: "__ASSETS__", with: String(data: try JSONEncoder().encode(assets), encoding: .utf8)!)
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    private func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}

private let compareTemplate = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SwiftDraw Compare</title>
<style>
__STYLE__
.sub { color:var(--muted); font-size:12px; }
.badge { font-size:11px; font-weight:600; padding:1px 7px; border-radius:10px; color:#fff; text-transform:uppercase; letter-spacing:.03em; }
.badge.regressed { background:var(--bad); } .badge.improved { background:var(--ok); }
.badge.changed { background:var(--warn); } .badge.unchanged { background:#8e8e93; } .badge.error { background:#5e5ce6; }
.row.regressed { border-left:4px solid var(--bad); } .row.improved { border-left:4px solid var(--ok); }
.row.changed { border-left:4px solid var(--warn); }
#summary span { margin-right:10px; font-weight:600; }
.delta.up { color:var(--bad); } .delta.down { color:var(--ok); }
</style>
</head>
<body>
<header>
  <div><h1>SwiftDraw Compare</h1><div class="sub">__BASE_LABEL__ → __HEAD_LABEL__</div></div>
  <input id="q" type="search" placeholder="Find file…  ( / )" autocomplete="off" spellcheck="false" style="width:14em">
  <label>Show <select id="show"><option value="changes">changes only</option><option value="all">all files</option></select></label>
  <label>Zoom <input id="zoom" type="range" min="0.5" max="4" step="0.25" value="1"><span id="zoomv">1×</span></label>
  <span id="summary" class="meta"></span>
  <span class="meta" id="ua"></span>
  <span id="note"></span>
</header>
<main id="list"></main>
<script>window.ASSETS = __ASSETS__;</script>
<script>
const ROWS = __ROWS__;
const SCALE = __SCALE__;
const TOLERANCE = __TOLERANCE__;   // percentage points
const BLUR = Math.round(SCALE);
const THRESHOLD = 32;
const ASSETS = window.ASSETS || {};
const ORDER = { regressed: 0, error: 1, improved: 2, changed: 3, unchanged: 4 };

__SHARED_JS__

const list = document.getElementById('list');
const note = document.getElementById('note');
const searchInput = document.getElementById('q');
const showSelect = document.getElementById('show');
document.getElementById('ua').textContent = browserName();
showSelect.value = store.get('compare.show') ?? 'changes';

const statusLabel = s => ({ 'swiftdraw-nil': 'parse failed', rendered: 'rendered' })[s] ?? s;
const pct = s => s == null ? '—' : (s * 100).toFixed(2) + '%';

function frame(src, w, h, cls = '') {
  return src ? `<img class="z ${cls}" src="${src}" data-w="${w}" data-h="${h}">`
             : `<div class="err" style="padding:8px;line-height:1.4">no image</div>`;
}

function rowEl(r) {
  const el = document.createElement('section');
  el.className = 'row';
  el.id = r.name;
  const a = ASSETS[r.name] || {}, w = r.w, h = r.h;
  el.innerHTML = `
    <h2><a href="#${r.name}">${r.name}</a> <span class="badge">…</span> <span class="score">comparing…</span>
        <span class="meta">${w}×${h}</span></h2>
    <div class="cells">
      <figure><figcaption>Browser (live SVG)</figcaption><div class="frame">${frame(a.svg, w, h)}</div></figure>
      <figure><figcaption>Base · <span class="bs">${statusLabel(r.baseStatus)}</span></figcaption><div class="frame">${frame(a.base, w, h)}</div></figure>
      <figure><figcaption>Head · <span class="hs">${statusLabel(r.headStatus)}</span></figcaption><div class="frame">${frame(a.head, w, h)}</div></figure>
      <figure><figcaption>Base → head (red = changed)</figcaption><div class="frame"><canvas class="z change" data-w="${w}" data-h="${h}"></canvas></div></figure>
      <figure><figcaption>Head vs browser (red = differs)</figcaption><div class="frame"><canvas class="z headdiff" data-w="${w}" data-h="${h}"></canvas></div></figure>
      <figure class="flip"><figcaption>Flip (hover / click): base → head</figcaption><div class="frame">${frame(a.base, w, h, 'a')}${frame(a.head, w, h, 'b')}</div></figure>
    </div>`;
  el.querySelector('.flip').addEventListener('click', e => e.currentTarget.classList.toggle('on'));
  r.el = el;
  r.score = null;
  return el;
}

function paint(canvas, image, w, h) {
  canvas.width = w; canvas.height = h;
  canvas.getContext('2d').putImageData(image, 0, 0);
}

async function compareRow(r) {
  const a = ASSETS[r.name] || {};
  const pw = Math.round(r.w * SCALE), ph = Math.round(r.h * SCALE);
  r.baseScore = null; r.headScore = null; r.changed = null;
  try {
    if (r.baseStatus !== 'rendered' && r.headStatus !== 'rendered') {
      // Fails on both sides (e.g. an intentionally invalid SVG): nothing changed.
      r.category = r.baseStatus === r.headStatus ? 'unchanged' : 'changed';
      throw { handled: true };
    }
    if (!a.svg || !pw) throw new Error('nothing to compare');
    const browser = await drawChecked(a.svg, pw, ph, r, 'browser svg');
    const base = a.base ? await drawChecked(a.base, pw, ph, r, 'base png') : null;
    const head = a.head ? await drawChecked(a.head, pw, ph, r, 'head png') : null;
    if (base) r.baseScore = diff(browser, base, pw, ph).score;
    if (head) {
      const d = diff(browser, head, pw, ph);
      r.headScore = d.score;
      paint(r.el.querySelector('canvas.headdiff'), d.image, pw, ph);
    }
    if (base && head) {
      // Exact comparison: no blur, tiny threshold, so any real change shows.
      const c = diff(base, head, pw, ph, 0, 2);
      r.changed = c.differing;
      paint(r.el.querySelector('canvas.change'), c.image, pw, ph);
    }
    if (!base && !head) r.category = 'unchanged';            // fails on both sides
    else if (!head) r.category = 'regressed';                 // head no longer renders
    else if (!base) r.category = 'improved';                  // head renders, base didn't
    else {
      const delta = (r.headScore - r.baseScore) * 100;
      r.category = delta > TOLERANCE ? 'regressed' : delta < -TOLERANCE ? 'improved' : r.changed > 0 ? 'changed' : 'unchanged';
    }
  } catch (e) {
    if (e && e.handled) { /* category already set */ } else {
    r.category = 'error';
    r.error = e.name + ': ' + e.message;
    if (e.name === 'SecurityError') note.textContent = 'Diff blocked by the browser (canvas tainted)';
    }
  }
  const badge = r.el.querySelector('.badge');
  badge.textContent = r.category;
  badge.className = 'badge ' + r.category;
  r.el.classList.add(r.category);
  const scoreEl = r.el.querySelector('.score');
  if (r.category === 'error') {
    scoreEl.textContent = r.error;
    scoreEl.className = 'score meta';
  } else {
    const delta = (r.baseScore != null && r.headScore != null) ? (r.headScore - r.baseScore) * 100 : null;
    const dTxt = delta == null ? '' : ` <span class="delta ${delta > 0.005 ? 'up' : delta < -0.005 ? 'down' : ''}">(${delta >= 0 ? '+' : ''}${delta.toFixed(2)})</span>`;
    const px = r.changed ? ` <span class="meta">· ${r.changed.toLocaleString()} px changed</span>` : '';
    const side = (score, status) => score != null ? pct(score) : statusLabel(status);
    scoreEl.innerHTML = `vs browser: base ${side(r.baseScore, r.baseStatus)} → head ${side(r.headScore, r.headStatus)}${dTxt}${px}`;
    scoreEl.className = 'score';
  }
  r.score = r.headScore ?? 1; // marks the row as done for progress reporting
}

function isVisible(r) {
  const q = searchInput.value.trim().toLowerCase();
  if (q) return r.name.toLowerCase().includes(q);
  if (showSelect.value === 'all') return true;
  return r.category === undefined || r.category !== 'unchanged';
}

function update() {
  const counts = {};
  for (const r of ROWS) {
    r.el.style.display = isVisible(r) ? '' : 'none';
    if (r.category) counts[r.category] = (counts[r.category] || 0) + 1;
  }
  const pending = ROWS.filter(r => !r.category).length;
  document.getElementById('summary').innerHTML =
    ['regressed', 'improved', 'changed', 'error', 'unchanged']
      .filter(k => counts[k]).map(k => `<span class="delta ${k === 'regressed' ? 'up' : k === 'improved' ? 'down' : ''}">${counts[k]} ${k}</span>`).join('')
    + (pending ? `<span>${pending} comparing…</span>` : '');
}

function sortRows() {
  const rows = [...ROWS].sort((a, b) =>
    (ORDER[a.category] ?? 9) - (ORDER[b.category] ?? 9) ||
    Math.abs((b.headScore ?? 0) - (b.baseScore ?? 0)) - Math.abs((a.headScore ?? 0) - (a.baseScore ?? 0)) ||
    a.name.localeCompare(b.name));
  rows.forEach(r => list.appendChild(r.el));
}

ROWS.forEach(r => list.appendChild(rowEl(r)));
applyZoom();
document.getElementById('zoom').addEventListener('input', applyZoom);
showSelect.addEventListener('change', () => { store.set('compare.show', showSelect.value); update(); });
searchInput.addEventListener('input', () => { update(); window.scrollTo(0, 0); });
searchInput.addEventListener('keydown', e => {
  if (e.key === 'Enter') { e.preventDefault(); [...list.children].find(el => el.style.display !== 'none')?.scrollIntoView({ block: 'start' }); }
  if (e.key === 'Escape') { searchInput.value = ''; update(); searchInput.blur(); }
});
document.addEventListener('keydown', e => {
  if (e.key === '/' && document.activeElement !== searchInput && !/INPUT|SELECT|TEXTAREA/.test(document.activeElement.tagName)) {
    e.preventDefault(); searchInput.focus(); searchInput.select();
  }
});

(async () => {
  update();
  for (const r of ROWS) { await compareRow(r); update(); }
  sortRows();
  update();
  window.EYEBALL_DONE = true; // polled by the CLI's hidden WKWebView
})();
</script>
</body>
</html>
"""#
