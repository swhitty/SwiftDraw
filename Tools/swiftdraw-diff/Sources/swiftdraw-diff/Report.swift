import Foundation
import SwiftDrawDiffCore

/// Shared setup for both modes.
struct Session {
    var options: Options
    var repo: Repo
    var cache: RenderCache
    var webkit: WebKitRenderer
    var resvg: ResvgRenderer?

    static func start(_ options: Options) async throws -> Session {
        let repo = try await Repo.find()
        let cache = RenderCache(root: options.useCache ? (options.cache ?? RenderCache.defaultRoot) : nil)
        let resvg = try await ResvgRenderer.prepare(options)  // first: fail fast when resvg is missing
        let webkit = try await WebKitRenderer.prepare(options, repo: repo)
        return Session(options: options, repo: repo, cache: cache, webkit: webkit, resvg: resvg)
    }

    func revision(_ ref: String?) async throws -> Revision {
        if let path = options.swiftdrawPath { return .binary(path) }
        guard let ref else { return .workingCopy }
        return .commit(ref: ref, sha: try await git(["rev-parse", "--verify", "\(ref)^{commit}"], in: repo.root))
    }

    var os: String { "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)" }
    var engine: String { "WebKit \(webkit.version)" }
}

/// `swiftdraw-diff [report]`: scores one SwiftDraw revision.
struct Reporter {
    var session: Session
    var options: Options { session.options }

    func run() async throws -> Int32 {
        let dirs = OutputDirs(
            root: options.out ?? session.repo.work.appendingPathComponent("report"),
            headName: "swiftdraw"
        )
        try dirs.create(base: false, resvg: session.resvg != nil)
        let files = try Pipeline.inputs(options, dirs: dirs, base: false)
        let head = try await SwiftDrawRenderer.prepare(
            try await session.revision(options.head),
            slot: "head",
            repo: session.repo,
            cache: session.cache,
            scale: options.scale
        )
        print("Scoring SwiftDraw \(head.label)")
        let rendered = try await Pipeline.render(
            files,
            options: options,
            cache: session.cache,
            dirs: dirs,
            webkit: session.webkit,
            head: head,
            base: nil,
            resvg: session.resvg
        )

        let progress = Progress("Scoring", total: rendered.count)
        let scores = await concurrentMap(rendered) { r -> ScoresReport.Score in
            defer { progress.tick() }
            return score(r, dirs: dirs)
        }
        let report = ScoresReport(
            swiftdraw: head.label,
            engine: session.engine,
            resvg: session.resvg?.label,
            os: session.os,
            scale: options.scale,
            match: options.match,
            fontSmoothing: options.fontSmoothing,
            textReference: session.resvg == nil ? "webkit" : "resvg",
            generated: Date(),
            results: scores
        )
        let json = dirs.root.appendingPathComponent("scores.json")
        try JSONEncoder.report.encode(report).write(to: json)
        printSummary(report)
        if options.html {
            let page = dirs.root.appendingPathComponent("index.html")
            try HTMLReport.write(report: report, dirs: dirs, to: page)
            print("\nVisual report: \(page.path)")
        }
        print("Scores: \(json.path)")
        return 0
    }

    func score(_ r: RenderedFile, dirs: OutputDirs) -> ScoresReport.Score {
        let name = r.file.name
        var errors: [String: String] = [:]
        func note(_ key: String, _ result: RenderResult?) { if let e = result?.error { errors[key] = e } }
        note("swiftdraw", r.head)
        note("webkit", r.webkitResult)
        note("resvg", r.resvg)

        var score = ScoresReport.Score(name: name, status: "scored", size: r.size, redrawn: r.webkit?.redrawn)
        guard let px = Pipeline.pixels(r, scale: options.scale) else {
            score.status = r.head.rendered ? "no-reference" : "swiftdraw-failed"
            score.errors = errors.isEmpty ? nil : errors
            return score
        }
        func load(_ key: String, _ dir: URL, _ result: RenderResult?, fit: Bool = false) -> Bitmap? {
            guard result?.rendered == true else { return nil }
            switch Pipeline.load(dirs.png(dir, name), size: px, fit: fit) {
            case let .success(b): return b
            case let .failure(e): errors[key] = e.description; return nil
            }
        }
        let swiftdraw = load("swiftdraw", dirs.head, r.head)
        let webkit = load("webkit", dirs.webkit, r.webkitResult)
        let resvg = load("resvg", dirs.resvg, r.resvg, fit: true)
        let blur = Diff.blur(scale: options.scale)

        if let swiftdraw, let webkit, let d = Diff.compare(webkit, swiftdraw, blur: blur) {
            score.score = d.score
            try? d.image.writePNG(to: dirs.diff.appendingPathComponent("\(name).webkit.png"))
        }
        if let swiftdraw, let resvg, let d = Diff.compare(resvg, swiftdraw, blur: blur) {
            score.resvg = d.score
            try? d.image.writePNG(to: dirs.diff.appendingPathComponent("\(name).resvg.png"))
        }
        if let webkit, let resvg {
            score.webkitResvg = Diff.compare(webkit, resvg, blur: blur)?.score
        }
        // With resvg, text is judged by resvg alone: WebKit's <img> path offsets middle- and end-anchored text.
        let text = session.resvg != nil && r.file.text
        if text { score.text = true }
        score.resvgSource = r.resvg?.source
        if let w = score.score, let s = score.resvg, let wr = score.webkitResvg {
            score.verdict = Verdict(webkit: w, resvg: s, webkitResvg: wr, match: options.match / 100, text: text)
        }
        if swiftdraw == nil {
            score.status = "swiftdraw-failed"
        } else if score.score == nil && score.resvg == nil {
            score.status = "no-reference"
        }
        score.errors = errors.isEmpty ? nil : errors
        return score
    }

    // MARK: - Summary

    func printSummary(_ report: ScoresReport) {
        let hasResvg = report.resvg != nil
        let results = report.results.sorted { a, b in
            let ra = a.verdict?.rank ?? (a.status == "scored" ? 5 : -1),
                rb = b.verdict?.rank ?? (b.status == "scored" ? 5 : -1)
            if ra != rb { return ra < rb }
            let sa = max(a.score ?? 2, a.resvg ?? 0), sb = max(b.score ?? 2, b.resvg ?? 0)
            return sa != sb ? sa > sb : a.name < b.name
        }
        let width = max(8, results.map(\.name.count).max() ?? 8)
        let refs = [report.engine, report.resvg].compactMap { $0 }.joined(separator: " and ")
        print("\nDifference from \(refs) · \(report.os) · font smoothing \(report.fontSmoothing ? "on" : "off")")
        if report.textReference == "resvg" {
            printTextSummary(
                sources: report.results.filter { $0.text == true }.map(\.resvgSource),
                pngs: options.resvgPNG != nil,
                marked: true
            )
        }
        print("")
        var header = "file".padded(width) + "      WebKit"
        if hasResvg { header += "       resvg  WebKit↔resvg  verdict" }
        print(header)
        print(String(repeating: "-", count: header.count + (hasResvg ? 8 : 0)))
        for s in results {
            var line = s.name.padded(width) + " " + percent(s.score, s.errors?["webkit"] != nil)
            if hasResvg {
                line +=
                    " " + percent(s.resvg, s.errors?["resvg"] != nil) + "  "
                    + percent(s.webkitResvg, false).leftPadded(12)
                line += "  " + (s.verdict?.label ?? "") + (s.text == true ? " *" : "")
                if options.resvgPNG != nil, s.resvgSource == "cli" { line += " (resvg CLI)" }
            }
            if s.status == "swiftdraw-failed" {
                line = s.name.padded(width) + "  SwiftDraw failed: " + (s.errors?["swiftdraw"] ?? "?")
            } else if s.status == "no-reference" {
                line = s.name.padded(width) + "  no reference rendered: " + (s.errors?["webkit"] ?? "?")
            }
            print(line)
        }

        let redrawn = report.results.filter { $0.redrawn != nil }
        if !redrawn.isEmpty {
            print("\nRedrawn (\(redrawn.count)) — WebKit's first draw was blank, scored from a later one")
            for s in redrawn { print("  \(s.name): \(s.redrawn!) \(s.redrawn == 1 ? "retry" : "retries")") }
        }
        let errors = report.results.filter { s in s.status == "scored" && s.errors != nil }
        if !errors.isEmpty {
            print("\nReference errors (\(errors.count))")
            for s in errors {
                print(
                    "  \(s.name): "
                        + s.errors!.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
                )
            }
        }

        func stats(_ values: [Double]) -> String {
            let mean = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            return String(
                format: "%d under 1%% · %d under 5%% · mean %.2f%%",
                values.filter { $0 < 0.01 }.count,
                values.filter { $0 < 0.05 }.count,
                mean * 100
            )
        }
        let failed = report.results.filter { $0.status == "swiftdraw-failed" }.count
        print("\n\(report.results.count) files\(failed > 0 ? " · \(failed) SwiftDraw failed" : "")")
        print("vs WebKit: " + stats(report.results.compactMap(\.score)))
        if hasResvg {
            print("vs resvg:  " + stats(report.results.compactMap(\.resvg)))
            let counts = Verdict.allCases.sorted { $0.rank > $1.rank }.map { v in
                "\(report.results.filter { $0.verdict == v }.count) \(v.label)"
            }
            print(String(format: "Verdicts (match < %g%%): ", report.match) + counts.joined(separator: " · "))
        }
    }
}

/// The text rule, and where text files' resvg images came from. `sources` holds each text file's resvg
/// source ("png", "cli" or nil); `pngs` is whether pre-rendered PNGs were given.
func printTextSummary(sources: [String?], pngs: Bool, marked: Bool = false) {
    func files(_ n: Int) -> String { "\(n) file\(n == 1 ? "" : "s")" }
    print(
        "Text: judged by resvg only (\(files(sources.count)) with <text>\(marked ? ", marked *" : "")); WebKit offsets middle- and end-anchored text, so its score is for information"
    )
    guard pngs else { return }
    let cli = sources.filter { $0 == "cli" }.count, png = sources.filter { $0 == "png" }.count
    if cli > 0 {
        print(
            "      \(files(cli)) with text rendered by the resvg CLI with SwiftDraw's fallback fonts, not from their PNG"
        )
    }
    if png > 0 {
        print(
            "      \(files(png)) with text compared against pre-rendered PNGs, which may use other fonts (resvg's suite uses Noto); add --resvg to render text with the CLI"
        )
    }
}

func percent(_ value: Double?, _ failed: Bool) -> String {
    if let value { return String(format: "%11.2f%%", value * 100) }
    return (failed ? "failed" : "–").leftPadded(12)
}

extension String {
    func padded(_ width: Int) -> String { padding(toLength: max(width, count), withPad: " ", startingAt: 0) }
    func leftPadded(_ width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
