import Foundation
import SwiftDrawDiffCore

/// `--html`: a self-contained page for people (every image embedded as a data: URI, so it is large).
/// Scores come from the CLI; the page only shows them. A "Live SVG" column shows the original SVG
/// as the browser viewing the page draws it, unscored, so it can be checked in other browsers.
enum HTMLReport {

    struct Row: Encodable {
        var name: String
        var w: Int
        var h: Int
        /// Shown next to the name.
        var summary: String
        /// "regressed", "swiftdraw-bug", … for the badge and filtering.
        var badge: String
        /// Sort key, worst first.
        var rank: Double
        /// Rows hidden by "problems only".
        var problem: Bool
        var cells: [Cell]
    }

    struct Cell: Encodable {
        var label: String
        /// Key into ASSETS.
        var asset: String
    }

    static func write(report: ScoresReport, dirs: OutputDirs, to url: URL) throws {
        var assets: [String: String] = [:]
        let rows = report.results.map { s -> Row in
            let cells = cells(
                s.name,
                dirs: dirs,
                assets: &assets,
                [
                    ("Live SVG (this browser)", dirs.svg, "svg"), ("WebKit", dirs.webkit, "png"),
                    ("resvg", dirs.resvg, "png"),
                    ("SwiftDraw", dirs.head, "png"), ("vs WebKit", dirs.diff, "webkit.png"),
                    ("vs resvg", dirs.diff, "resvg.png"),
                ]
            )
            var summary = "WebKit \(pct(s.score))"
            if report.resvg != nil { summary += " · resvg \(pct(s.resvg)) · WebKit↔resvg \(pct(s.webkitResvg))" }
            if let errors = s.errors {
                summary +=
                    " · " + errors.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
            }
            let worst = max(s.score ?? 1, s.resvg ?? 0)
            return Row(
                name: s.name,
                w: s.size?.width ?? 0,
                h: s.size?.height ?? 0,
                summary: summary,
                badge: s.verdict?.rawValue ?? (s.status == "scored" ? "" : s.status),
                rank: worst,
                problem: s.status != "scored" || (s.verdict.map { $0 != .pass } ?? (worst >= report.match / 100)),
                cells: cells
            )
        }
        try write(
            title: "SwiftDraw Report",
            subtitle: "\(report.swiftdraw) · \(report.engine)\(report.resvg.map { " · \($0)" } ?? "")",
            rows: rows,
            assets: assets,
            to: url
        )
    }

    static func write(compare report: CompareReport, dirs: OutputDirs, to url: URL) throws {
        var assets: [String: String] = [:]
        let order: [CompareCategory: Double] = [
            .regressed: 5, .error: 4, .mixed: 3, .noSecondReference: 3, .improved: 2, .changed: 1, .unchanged: 0,
        ]
        let rows = report.results.map { e -> Row in
            let cells = cells(
                e.name,
                dirs: dirs,
                assets: &assets,
                [
                    ("Live SVG (this browser)", dirs.svg, "svg"), ("WebKit", dirs.webkit, "png"),
                    ("resvg", dirs.resvg, "png"),
                    ("Base", dirs.base, "png"), ("Head", dirs.head, "png"), ("Head vs WebKit", dirs.diff, "webkit.png"),
                    ("Head vs resvg", dirs.diff, "resvg.png"), ("Base → head", dirs.diff, "change.png"),
                ]
            )
            var summary = "WebKit \(pct(e.base, scale: 1)) → \(pct(e.head, scale: 1))"
            if report.resvg != nil {
                summary += " · resvg \(pct(e.baseResvg, scale: 1)) → \(pct(e.headResvg, scale: 1))"
            }
            if let b = e.baseVerdict, let h = e.headVerdict {
                summary += " · \(b.label)\(b == h ? "" : " → \(h.label)")"
            }
            if let px = e.pixelsChanged, px > 0 { summary += " · \(px) px changed" }
            return Row(
                name: e.name,
                w: e.size?.width ?? 0,
                h: e.size?.height ?? 0,
                summary: summary,
                badge: e.category.rawValue,
                rank: (order[e.category] ?? 0) * 1000 + max(abs(e.delta ?? 0), abs(e.deltaResvg ?? 0)),
                problem: e.category != .unchanged,
                cells: cells
            )
        }
        try write(
            title: "SwiftDraw Compare",
            subtitle: "\(report.base) → \(report.head) · \(report.engine)\(report.resvg.map { " · \($0)" } ?? "")",
            rows: rows,
            assets: assets,
            to: url
        )
    }

    private static func cells(
        _ name: String,
        dirs: OutputDirs,
        assets: inout [String: String],
        _ specs: [(String, URL, String)]
    ) -> [Cell] {
        specs.compactMap { label, dir, ext in
            let file = dir.appendingPathComponent("\(name).\(ext)")
            guard let data = try? Data(contentsOf: file) else { return nil }
            let key = "\(name)/\(label)"
            assets[key] = "data:\(ext == "svg" ? "image/svg+xml" : "image/png");base64," + data.base64EncodedString()
            return Cell(label: label, asset: key)
        }
    }

    private static func pct(_ v: Double?, scale: Double = 100) -> String {
        v.map { String(format: "%.2f%%", $0 * scale) } ?? "–"
    }

    private static func write(
        title: String,
        subtitle: String,
        rows: [Row],
        assets: [String: String],
        to url: URL
    ) throws {
        let encoder = JSONEncoder()  // escapes "/" as "\/", so the JSON can never close the <script> tag
        let html =
            template
            .replacingOccurrences(of: "__TITLE__", with: escape(title))
            .replacingOccurrences(of: "__SUBTITLE__", with: escape(subtitle))
            .replacingOccurrences(of: "__ROWS__", with: String(decoding: try encoder.encode(rows), as: UTF8.self))
            // last: large
            .replacingOccurrences(of: "__ASSETS__", with: String(decoding: try encoder.encode(assets), as: UTF8.self))
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(
            of: ">",
            with: "&gt;"
        )
    }

    private static let template = #"""
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>__TITLE__</title>
        <style>
        :root { --bg:#f3f3f1; --card:#fff; --ink:#1d1d1f; --muted:#6e6e73; --line:#e3e3e0; --ok:#2e8b57; --warn:#c98a00; --bad:#c8372d; }
        @media (prefers-color-scheme: dark) { :root { --bg:#161617; --card:#1f1f21; --ink:#f2f2f2; --muted:#9a9a9f; --line:#333336; } }
        * { box-sizing:border-box; }
        body { margin:0; font:13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background:var(--bg); color:var(--ink); }
        header { position:sticky; top:0; z-index:2; background:var(--bg); border-bottom:1px solid var(--line); padding:10px 16px;
                 display:flex; flex-wrap:wrap; gap:16px; align-items:center; }
        header h1 { font-size:15px; margin:0; } .sub, .meta { color:var(--muted); font-size:12px; }
        header label { display:flex; gap:6px; align-items:center; color:var(--muted); }
        main { padding:16px; display:grid; gap:12px; }
        .row { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:10px 12px; }
        .row h2 { font-size:13px; margin:0 0 8px; display:flex; gap:10px; align-items:baseline; flex-wrap:wrap; }
        .row h2 a { color:inherit; }
        .badge { font-size:11px; font-weight:600; padding:1px 7px; border-radius:10px; color:#fff; background:#8e8e93; text-transform:uppercase; }
        .badge:empty { display:none; }
        .badge.regressed, .badge.swiftdraw-bug, .badge.swiftdraw-failed { background:var(--bad); }
        .badge.improved, .badge.pass { background:var(--ok); }
        .badge.mixed, .badge.no-second-reference, .badge.changed, .badge.unclear { background:var(--warn); }
        .cells { display:flex; gap:12px; flex-wrap:wrap; align-items:flex-start; }
        figure { margin:0; } figcaption { color:var(--muted); font-size:11px; margin-bottom:4px; }
        .frame { background:#fff; border:1px solid var(--line); line-height:0; }
        .frame img { display:block; }
        </style>
        </head>
        <body>
        <header>
          <div><h1>__TITLE__</h1><div class="sub">__SUBTITLE__</div></div>
          <input id="q" type="search" placeholder="Find file…  ( / )" autocomplete="off" spellcheck="false" style="width:14em">
          <label><input id="problems" type="checkbox" checked> problems only</label>
          <label>Zoom <input id="zoom" type="range" min="0.5" max="4" step="0.25" value="1"><span id="zoomv">1×</span></label>
          <span id="count" class="meta"></span>
        </header>
        <main id="list"></main>
        <script>window.ASSETS = __ASSETS__;</script>
        <script>
        const ROWS = __ROWS__;
        const list = document.getElementById('list'), q = document.getElementById('q');
        const problems = document.getElementById('problems'), zoom = document.getElementById('zoom');
        ROWS.sort((a, b) => b.rank - a.rank || a.name.localeCompare(b.name));
        for (const r of ROWS) {
          const el = document.createElement('section');
          el.className = 'row'; el.id = r.name;
          const h2 = document.createElement('h2');
          h2.innerHTML = `<a href="#${encodeURIComponent(r.name)}"></a> <span class="badge ${r.badge}"></span> <span class="meta"></span>`;
          h2.querySelector('a').textContent = r.name;
          h2.querySelector('.badge').textContent = r.badge;
          h2.querySelector('.meta').textContent = r.summary + (r.w ? ` · ${r.w}×${r.h} pt` : '');
          const cells = document.createElement('div'); cells.className = 'cells';
          for (const c of r.cells) {
            const f = document.createElement('figure');
            f.innerHTML = '<figcaption></figcaption><div class="frame"><img loading="lazy"></div>';
            f.querySelector('figcaption').textContent = c.label;
            const img = f.querySelector('img'); img.src = window.ASSETS[c.asset]; img.dataset.w = r.w; img.dataset.h = r.h;
            cells.appendChild(f);
          }
          el.append(h2, cells); r.el = el; list.appendChild(el);
        }
        function update() {
          const term = q.value.trim().toLowerCase(); let shown = 0;
          for (const r of ROWS) {
            const v = term ? r.name.toLowerCase().includes(term) : (!problems.checked || r.problem);
            r.el.style.display = v ? '' : 'none'; if (v) shown++;
          }
          document.getElementById('count').textContent = `showing ${shown} of ${ROWS.length}`;
        }
        function applyZoom() {
          const z = parseFloat(zoom.value); document.getElementById('zoomv').textContent = z + '×';
          document.querySelectorAll('img[data-w]').forEach(i => { if (+i.dataset.w) { i.style.width = i.dataset.w * z + 'px'; i.style.height = i.dataset.h * z + 'px'; } });
        }
        q.addEventListener('input', update); problems.addEventListener('change', update); zoom.addEventListener('input', applyZoom);
        document.addEventListener('keydown', e => { if (e.key === '/' && document.activeElement !== q) { e.preventDefault(); q.focus(); } });
        update(); applyZoom();
        </script>
        </body>
        </html>
        """#
}
