import AppKit
import SwiftDraw

struct Options {
    enum Command: String { case report, render, compare }
    var command = Command.report
    var inputs: [URL] = []
    var base = "main"
    var head: String?
    var tolerance = 0.5
    var outIsDefault = true
    var out = URL(fileURLWithPath: ".build/report")
    var scale: CGFloat = 2
    var repeatCount = 1
    var useWindow = true
    var maxDimension: CGFloat = 1024
    var blur = 1
    var webkit = false
    /// Keep WebKit's font smoothing in the reference (off by default; see ReferenceSVG)
    var fontSmoothing = false
    var hideBelow = 1.0
    var score = true
    /// Write the visual HTML report (large: every image is embedded). Off by default.
    var html = false

    static func parse(_ args: [String]) -> Options? {
        var o = Options()
        var rest = args.dropFirst()
        if let first = rest.first, let command = Command(rawValue: first) {
            o.command = command
            o.out = URL(fileURLWithPath: command == .compare ? ".build/compare/report" : ".build/report")
            rest = rest.dropFirst()
        }
        var it = rest.makeIterator()
        while let a = it.next() {
            switch a {
            case "--out": guard let v = it.next() else { return nil }; o.out = URL(fileURLWithPath: v); o.outIsDefault = false
            case "--base": guard let v = it.next() else { return nil }; o.base = v
            case "--head": guard let v = it.next() else { return nil }; o.head = v
            case "--tolerance": guard let v = it.next().flatMap(Double.init) else { return nil }; o.tolerance = v
            case "--scale": guard let v = it.next().flatMap(Double.init) else { return nil }; o.scale = v
            case "--repeat": guard let v = it.next().flatMap(Int.init) else { return nil }; o.repeatCount = max(1, v)
            case "--max": guard let v = it.next().flatMap(Double.init) else { return nil }; o.maxDimension = v
            case "--blur": guard let v = it.next().flatMap(Int.init) else { return nil }; o.blur = v
            case "--no-window": o.useWindow = false
            case "--webkit": o.webkit = true
            case "--font-smoothing": o.fontSmoothing = true
            case "--no-score": o.score = false
            case "--html": o.html = true
            case "--hide-below": guard let v = it.next().flatMap(Double.init) else { return nil }; o.hideBelow = v
            case _ where a.hasPrefix("--"): return nil
            default: o.inputs.append(URL(fileURLWithPath: a))
            }
        }
        return o.inputs.isEmpty ? nil : o
    }

    var svgFiles: [URL] {
        inputs.flatMap { url -> [URL] in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            guard isDir.boolValue else { return [url] }
            let items = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            return items.filter { $0.pathExtension.lowercased() == "svg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
    }
}

/// Prints the images the scoring page had to redraw because their first draw came out blank.
func printRedrawn(_ items: [(name: String, redrawn: [String])]) {
    guard !items.isEmpty else { return }
    print("Redrawn (\(items.count)) — first draw was blank, scored from a later one")
    for item in items { print("  \(item.name): \(item.redrawn.joined(separator: ", "))") }
}

struct Result {
    var name: String
    var size: CGSize
    var status: String
    var score: Double?
    var meanError: Double?
    var webkitMillis: [Double] = []
    var uniqueWebKitHashes = 0
    var maxRepeatScore = 0.0
    var info = ""
}

@MainActor
struct Runner {
    var options: Options

    func run() async throws {
        let fm = FileManager.default
        let imagesDir = options.out.appendingPathComponent("images")
        try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        let svgDir = options.out.appendingPathComponent("svg")
        try fm.createDirectory(at: svgDir, withIntermediateDirectories: true)

        let renderer = options.webkit ? WebKitRenderer(useWindow: options.useWindow) : nil
        if let renderer {
            print("WebKit backing scale: \(renderer.backingScale), compare scale: \(options.scale), window: \(options.useWindow), repeat: \(options.repeatCount)")
        }
        print("Output: \(options.out.standardizedFileURL.path)")

        var results: [Result] = []
        for url in options.svgFiles {
            let r = await process(url, renderer: renderer, imagesDir: imagesDir, svgDir: svgDir)
            results.append(r)
            let score = r.score.map { String(format: "%6.2f%%", $0 * 100) } ?? "     -"
            let ms = r.webkitMillis.map { String(format: "%.0f", $0) }.joined(separator: ",")
            let stable = options.repeatCount > 1 ? " hashes=\(r.uniqueWebKitHashes)" : ""
            print("\(r.status.padding(toLength: 14, withPad: " ", startingAt: 0)) \(score)  \(r.name)  [\(ms)ms\(stable)] \(r.info)")
        }

        // The page is also the scoring engine (its JS diffs against WebKit), so it is
        // always written when scoring; without --html it's a temporary file.
        let index = options.out.appendingPathComponent("index.html")
        let page = options.html ? index : options.out.appendingPathComponent(".scoring.html")
        if !options.html { try? fm.removeItem(at: index) } // don't leave a stale report behind
        if options.html || options.score {
            try writeEyeball(results, scale: options.scale, hideBelow: options.hideBelow, to: page)
        }
        if renderer != nil {
            try writeReport(results, to: options.out.appendingPathComponent("report.html"))
            summarize(results)
        }
        if options.score {
            try await printScores(report: page)
        }
        if options.html {
            print("\nVisual report: \(index.standardizedFileURL.path)")
        } else {
            try? fm.removeItem(at: page)
        }
    }

    func process(_ url: URL, renderer: WebKitRenderer?, imagesDir: URL, svgDir: URL) async -> Result {
        let name = url.deletingPathExtension().lastPathComponent
        guard let data = try? Data(contentsOf: url) else {
            return Result(name: name, size: .zero, status: "read-failed")
        }
        let reference = ReferenceSVG.prepare(data, fontSmoothing: options.fontSmoothing)
        try? reference.write(to: svgDir.appendingPathComponent("\(name).svg"))
        guard let svg = SVG(data: data) else {
            return Result(name: name, size: .zero, status: "swiftdraw-nil")
        }

        // Point size, clamped so huge SVGs stay manageable.
        var size = svg.size
        let longest = max(size.width, size.height)
        if longest > options.maxDimension { size = CGSize(width: size.width * options.maxDimension / longest, height: size.height * options.maxDimension / longest) }
        size = CGSize(width: max(1, size.width.rounded()), height: max(1, size.height.rounded()))
        var result = Result(name: name, size: size, status: "")

        let pw = Int(size.width * options.scale), ph = Int(size.height * options.scale)

        // SwiftDraw: draw unflipped, then flip the rows for a top-left origin (see renderSwiftDraw).
        guard let swiftdraw = Bitmap.render(width: pw, height: ph, draw: { ctx in
            ctx.draw(svg, in: CGRect(x: 0, y: 0, width: pw, height: ph))
        })?.flippedVertically() else {
            result.status = "bitmap-failed"; return result
        }
        try? swiftdraw.writePNG(to: imagesDir.appendingPathComponent("\(name).swiftdraw.png"))
        guard let renderer else {
            result.status = "rendered"
            return result
        }

        // WebKit, optionally several times to measure determinism.
        var snapshots: [Bitmap] = []
        for _ in 0..<options.repeatCount {
            let start = Date()
            do {
                let snap = try await renderer.render(svg: reference, size: size)
                result.webkitMillis.append(Date().timeIntervalSince(start) * 1000)
                result.info = snap.info
                guard let bmp = Bitmap.render(width: pw, height: ph, draw: { ctx in
                    ctx.draw(snap.image, in: CGRect(x: 0, y: 0, width: pw, height: ph))
                }) else { continue }
                snapshots.append(bmp)
            } catch {
                result.webkitMillis.append(Date().timeIntervalSince(start) * 1000)
                result.info = "\(error)"
            }
        }
        guard let webkit = snapshots.first else {
            result.status = "webkit-failed"
            try? swiftdraw.writePNG(to: imagesDir.appendingPathComponent("\(name).swiftdraw.png"))
            return result
        }
        result.uniqueWebKitHashes = Set(snapshots.map(\.sha256)).count
        for s in snapshots.dropFirst() {
            if let d = Diff.compare(webkit, s, blur: 0, threshold: 0) {
                result.maxRepeatScore = max(result.maxRepeatScore, d.score)
            }
        }

        try? webkit.writePNG(to: imagesDir.appendingPathComponent("\(name).webkit.png"))
        try? swiftdraw.writePNG(to: imagesDir.appendingPathComponent("\(name).swiftdraw.png"))

        if webkit.isBlank && !swiftdraw.isBlank {
            result.status = "webkit-blank"
            return result
        }

        guard let diff = Diff.compare(webkit, swiftdraw, blur: options.blur * Int(options.scale.rounded())) else {
            result.status = "size-mismatch"; return result
        }
        try? diff.image.writePNG(to: imagesDir.appendingPathComponent("\(name).diff.png"))
        result.score = diff.score
        result.meanError = diff.meanError
        switch diff.score {
        case ..<0.01: result.status = "match"
        case ..<0.05: result.status = "close"
        case ..<0.20: result.status = "differs"
        default: result.status = "fail"
        }
        return result
    }

    /// Scores every SVG against WebKit via a hidden WKWebView and prints a table.
    func printScores(report: URL) async throws {
        let scores = try await Scorer.score(report: report, progress: progressPrinter("Scoring against WebKit"))

        let jsonURL = options.out.appendingPathComponent("scores.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(scores).write(to: jsonURL)

        let sorted = scores.results.sorted { ($0.score ?? 2) > ($1.score ?? 2) }
        let width = max(8, sorted.map(\.name.count).max() ?? 8)
        print("\nDifference from \(scores.engine) (\(scores.os)), font smoothing \(options.fontSmoothing ? "on" : "off")\n")
        print("file".padding(toLength: width, withPad: " ", startingAt: 0) + "   diff")
        print(String(repeating: "-", count: width + 9))
        for s in sorted {
            let value: String
            if let score = s.score { value = String(format: "%6.2f%%", score * 100) }
            else if s.status == "swiftdraw-nil" { value = "  parse failed" }
            else { value = "  error" + (s.error.map { " (\($0))" } ?? "") }
            print(s.name.padding(toLength: width, withPad: " ", startingAt: 0) + " " + value)
        }
        let scored = scores.results.compactMap(\.score)
        let under1 = scored.filter { $0 < 0.01 }.count, under5 = scored.filter { $0 < 0.05 }.count
        let mean = scored.isEmpty ? 0 : scored.reduce(0, +) / Double(scored.count)
        if scores.results.contains(where: { $0.redrawn != nil }) { print("") }
        printRedrawn(scores.results.compactMap { s in s.redrawn.map { (s.name, $0) } })
        print(String(format: "\n%d files · %d under 1%% · %d under 5%% · mean %.2f%%", scores.results.count, under1, under5, mean * 100))
        print("Scores: \(jsonURL.standardizedFileURL.path)")
    }

    func summarize(_ results: [Result]) {
        var counts: [String: Int] = [:]
        results.forEach { counts[$0.status, default: 0] += 1 }
        print("\n== Summary (\(results.count) files) ==")
        for (k, v) in counts.sorted(by: { $0.value > $1.value }) { print("  \(k): \(v)") }

        let times = results.flatMap(\.webkitMillis).sorted()
        if !times.isEmpty {
            let median = times[times.count / 2]
            print(String(format: "  webkit ms: first=%.0f median=%.0f max=%.0f", results.first?.webkitMillis.first ?? 0, median, times.last!))
        }
        if options.repeatCount > 1 {
            let unstable = results.filter { $0.uniqueWebKitHashes > 1 }
            print("  non-deterministic webkit renders: \(unstable.count)")
            for r in unstable { print(String(format: "    %@ hashes=%d maxRepeatDiff=%.4f%%", r.name, r.uniqueWebKitHashes, r.maxRepeatScore * 100)) }
        }
        print("  report: \(options.out.appendingPathComponent("report.html").path)")
    }

    func writeReport(_ results: [Result], to url: URL) throws {
        let sorted = results.sorted { ($0.score ?? 2) > ($1.score ?? 2) }
        var rows = ""
        for r in sorted {
            let score = r.score.map { String(format: "%.2f%%", $0 * 100) } ?? "-"
            let img = { (kind: String) in "<img loading=lazy src=\"images/\(r.name).\(kind).png\" onerror=\"this.style.visibility='hidden'\">" }
            rows += """
            <tr class="\(r.status)"><td><b>\(r.name)</b><br>\(r.status)<br>\(score)<br><small>\(Int(r.size.width))×\(Int(r.size.height))</small></td>
            <td>\(img("webkit"))</td><td>\(img("swiftdraw"))</td><td>\(img("diff"))</td></tr>\n
            """
        }
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><title>SVG Reference Report</title><style>
        body{font:13px -apple-system,sans-serif;margin:16px;background:#f4f4f4}
        table{border-collapse:collapse;width:100%}
        td{border-bottom:1px solid #ddd;padding:8px;vertical-align:top;background:#fff}
        td img{max-width:300px;max-height:300px;border:1px solid #eee}
        tr.match td:first-child{border-left:4px solid #3a3} tr.close td:first-child{border-left:4px solid #9c3}
        tr.differs td:first-child{border-left:4px solid #e90} tr.fail td:first-child,tr[class*=failed] td:first-child,tr.webkit-blank td:first-child{border-left:4px solid #d33}
        </style></head><body><h1>SVG Reference Report</h1>
        <table><tr><th></th><th>WebKit</th><th>SwiftDraw</th><th>Diff</th></tr>
        \(rows)</table></body></html>
        """
        try html.write(to: url, atomically: true, encoding: .utf8)
    }
}

guard let options = Options.parse(Swift.CommandLine.arguments) else {
    print("""
    usage:
      swiftdraw-diff <file.svg | dir>... [--out dir] [--html] [--hide-below 1] [--no-score]
          Render with SwiftDraw and score each file against WebKit.

      swiftdraw-diff compare [--base main] [--head ref] <file.svg | dir>... [--out dir] [--tolerance 0.5] [--html]
          Render with SwiftDraw at --base and at --head (default: the working copy), score both against
          WebKit, and report regressions. Exits 1 if any file regressed by more than
          --tolerance percentage points.

      swiftdraw-diff render <file.svg | dir>... --out dir
          Render PNGs plus manifest.json only (used internally by compare).

    common: [--scale 2] [--max 1024] [--font-smoothing]
            --font-smoothing  keep WebKit's font smoothing in the reference (off by default, so text
                              is compared against its outlines, as SwiftDraw draws it)
            --html  also write index.html, a visual side-by-side report for people
                    (large: every image is embedded; agents should not read it)
    """)
    exit(1)
}

// render: no WebKit, no run loop needed.
if options.command == .render {
    do {
        let files = try renderAll(options.svgFiles, scale: options.scale, maxDimension: options.maxDimension, to: options.out)
        print("Rendered \(files.filter { $0.status == "rendered" }.count)/\(files.count) → \(options.out.path)")
        exit(0)
    } catch {
        print("error: \(error)")
        exit(1)
    }
}

setvbuf(stdout, nil, _IOLBF, 0)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
Task { @MainActor in
    do {
        switch options.command {
        case .compare:
            exit(try await Comparer(options: options).run())
        default:
            try await Runner(options: options).run()
            exit(0)
        }
    } catch {
        print("error: \(error)")
        exit(1)
    }
}
app.run()
