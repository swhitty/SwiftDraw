import Foundation

/// CSS shared by the eyeball and compare pages.
let sharedStyle = #"""
:root { --bg:#f3f3f1; --card:#fff; --ink:#1d1d1f; --muted:#6e6e73; --line:#e3e3e0;
        --ok:#2e8b57; --warn:#c98a00; --bad:#c8372d; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#161617; --card:#1f1f21; --ink:#f2f2f2; --muted:#9a9a9f; --line:#333336; }
}
* { box-sizing: border-box; }
body { margin:0; font:13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background:var(--bg); color:var(--ink); }
header { position:sticky; top:0; z-index:2; background:var(--bg); border-bottom:1px solid var(--line);
         padding:10px 16px; display:flex; flex-wrap:wrap; gap:16px; align-items:center; }
header h1 { font-size:15px; margin:0 8px 0 0; }
header label { display:flex; gap:6px; align-items:center; color:var(--muted); }
#note { color:var(--bad); }
main { padding:16px; display:grid; gap:12px; }
.row { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:10px 12px; }
.row h2 { font-size:13px; margin:0 0 8px; display:flex; gap:10px; align-items:baseline; flex-wrap:wrap; }
.row h2 a { color:inherit; }
.score { font-variant-numeric: tabular-nums; font-weight:600; }
.score.ok { color:var(--ok); } .score.warn { color:var(--warn); } .score.bad { color:var(--bad); }
.meta { color:var(--muted); font-weight:400; }
.cells { display:flex; gap:12px; flex-wrap:wrap; align-items:flex-start; }
figure { margin:0; }
figcaption { color:var(--muted); font-size:11px; margin-bottom:4px; }
.frame { background:#fff; border:1px solid var(--line); line-height:0; position:relative; }
.frame.checker { background: repeating-conic-gradient(#ddd 0% 25%, #fff 0% 50%) 0 0 / 16px 16px; }
.frame img, .frame canvas { display:block; image-rendering:auto; }
.flip .frame img.b { position:absolute; inset:0; opacity:0; }
.flip .frame:hover img.b, .flip.on .frame img.b { opacity:1; }
.err { color:var(--bad); }
"""#

/// JavaScript shared by the eyeball and compare pages.
/// Expects SCALE, BLUR and THRESHOLD constants to be defined by the page first.
let sharedScript = #"""
function browserName() {
  const ua = navigator.userAgent;
  if (/Edg\//.test(ua)) return 'Live SVG: Edge';
  if (/Chrome\//.test(ua)) return 'Live SVG: Chrome';
  if (/Firefox\//.test(ua)) return 'Live SVG: Firefox';
  if (/Safari\//.test(ua)) return 'Live SVG: Safari';
  return 'Live SVG: browser';
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => img.decode().then(() => resolve(img), () => resolve(img));
    img.onerror = () => reject(new Error('failed to load ' + src));
    img.src = src;
  });
}

function pixels(img, w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const ctx = c.getContext('2d');
  ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, w, h);
  ctx.drawImage(img, 0, 0, w, h);
  return ctx.getImageData(0, 0, w, h); // throws SecurityError on tainted canvas (file://)
}

function boxBlur(src, w, h, r) {
  if (r <= 0) return src;
  const tmp = new Float32Array(src.length), out = new Uint8ClampedArray(src.length);
  const k = 2 * r + 1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) for (let c = 0; c < 3; c++) {
    let s = 0;
    for (let i = -r; i <= r; i++) { const xx = Math.min(w - 1, Math.max(0, x + i)); s += src[(y * w + xx) * 4 + c]; }
    tmp[(y * w + x) * 4 + c] = s / k;
  }
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) for (let c = 0; c < 3; c++) {
    let s = 0;
    for (let i = -r; i <= r; i++) { const yy = Math.min(h - 1, Math.max(0, y + i)); s += tmp[(yy * w + x) * 4 + c]; }
    out[(y * w + x) * 4 + c] = s / k;
  }
  return out;
}

// Blurred, thresholded diff of two ImageData. score = differing ink pixels / ink pixels.
function diff(a, b, w, h, blur = BLUR, threshold = THRESHOLD) {
  const ba = boxBlur(a.data, w, h, blur), bb = boxBlur(b.data, w, h, blur);
  const out = new ImageData(w, h);
  let ink = 0, bad = 0;
  for (let p = 0; p < w * h; p++) {
    const i = p * 4;
    let d = 0, isInk = false;
    for (let c = 0; c < 3; c++) {
      d = Math.max(d, Math.abs(ba[i + c] - bb[i + c]));
      if (ba[i + c] < 245 || bb[i + c] < 245) isInk = true;
    }
    const lum = (a.data[i] * 3 + a.data[i + 1] * 6 + a.data[i + 2]) / 10;
    const faded = 200 + lum * 55 / 255;
    if (isInk) ink++;
    if (isInk && d > threshold) { bad++; out.data.set([230, 30, 30, 255], i); }
    else out.data.set([faded, faded, faded, 255], i);
  }
  return { score: ink ? bad / ink : 0, image: out, differing: bad, ink };
}

function scoreClass(s) { return s < 0.01 ? 'ok' : s < 0.05 ? 'warn' : 'bad'; }

function applyZoom() {
  const z = parseFloat(document.getElementById('zoom').value);
  document.getElementById('zoomv').textContent = z + '×';
  document.querySelectorAll('.z').forEach(el => {
    el.style.width = (el.dataset.w * z) + 'px';
    el.style.height = (el.dataset.h * z) + 'px';
  });
}

const store = {
  get(k) { try { return localStorage.getItem('eyeball.' + k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem('eyeball.' + k, v); } catch {} }
};
"""#

/// Reads a file as a data: URI (data: images never taint a canvas, so the
/// in-page pixel diff works from file:// with no server).
func dataURI(_ url: URL, type: String) -> String? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return "data:\(type);base64," + data.base64EncodedString()
}
