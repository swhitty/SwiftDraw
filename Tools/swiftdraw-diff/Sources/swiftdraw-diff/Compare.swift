import Foundation
import SwiftDrawDiffCore

/// `swiftdraw-diff compare --base <ref> [--head <ref>]`
///
/// 1. Builds swiftdrawcli at --base and at --head (default: the working copy), cached by commit.
/// 2. Renders every file with WebKit (which decides its size), SwiftDraw head and base, and resvg.
/// 3. Scores base and head against each reference and diffs base against head.
/// 4. Prints regressed / mixed / improved / changed files, writes compare.json and returns 1 if
///    anything regressed beyond the tolerance.
struct Comparer {
    var session: Session
    var options: Options { session.options }

    func run() async throws -> Int32 {
        let dirs = OutputDirs(root: options.out ?? session.repo.work.appendingPathComponent("compare/report"), headName: "head")
        try dirs.create(base: true, resvg: session.resvg != nil)
        let files = try Pipeline.inputs(options, copyTo: dirs.svg)

        let baseRevision = try await session.revision(options.base)
        let headRevision = try await session.revision(options.head)
        let base: SwiftDrawRenderer
        if case .binary = baseRevision {
            // --swiftdraw-path replaces head only
            let sha = try await git(["rev-parse", "--verify", "\(options.base)^{commit}"], in: session.repo.root)
            base = try await SwiftDrawRenderer.prepare(.commit(ref: options.base, sha: sha), slot: "base", repo: session.repo, cache: session.cache, scale: options.scale)
        } else {
            base = try await SwiftDrawRenderer.prepare(baseRevision, slot: "base", repo: session.repo, cache: session.cache, scale: options.scale)
        }
        let head = try await SwiftDrawRenderer.prepare(headRevision, slot: "head", repo: session.repo, cache: session.cache, scale: options.scale)
        print("Comparing SwiftDraw: \(base.label) → \(head.label)")
        if case let .commit(_, baseSHA) = baseRevision, case let .commit(_, headSHA) = headRevision, baseSHA == headSHA {
            print("note: base and head are the same commit; expect no differences")
        }

        let rendered = try await Pipeline.render(files, options: options, cache: session.cache, dirs: dirs,
                                                 webkit: session.webkit, head: head, base: base, resvg: session.resvg)
        let progress = Progress("Scoring", total: rendered.count)
        let entries = await concurrentMap(rendered) { r -> CompareReport.Entry in
            defer { progress.tick() }
            return entry(r, dirs: dirs)
        }

        let report = CompareReport(
            base: base.label, head: head.label, engine: session.engine, resvg: session.resvg?.label, os: session.os,
            scale: options.scale, tolerance: options.tolerance, match: options.match, fontSmoothing: options.fontSmoothing,
            generated: Date(), results: entries
        )
        let json = dirs.root.appendingPathComponent("compare.json")
        try JSONEncoder.report.encode(report).write(to: json)
        printSummary(report)
        if options.html {
            let page = dirs.root.appendingPathComponent("index.html")
            try HTMLReport.write(compare: report, dirs: dirs, to: page)
            print("\nReport: \(page.path)")
        }
        print("\nJSON:   \(json.path)")
        return entries.contains { $0.category == .regressed } ? 1 : 0
    }

    func entry(_ r: RenderedFile, dirs: OutputDirs) -> CompareReport.Entry {
        let name = r.file.name
        var errors: [String: String] = [:]
        func note(_ key: String, _ result: RenderResult?) { if let e = result?.error { errors[key] = e } }
        note("head", r.head)
        note("base", r.base)
        note("webkit", r.webkitResult)
        note("resvg", r.resvg)

        let baseRendered = r.base?.rendered == true, headRendered = r.head.rendered
        var e = CompareReport.Entry(
            name: name, category: .error,
            baseStatus: baseRendered ? "rendered" : "failed", headStatus: headRendered ? "rendered" : "failed",
            size: r.size, redrawn: r.webkit?.redrawn
        )
        guard let px = Pipeline.pixels(r, scale: options.scale) else {
            e.category = CompareCategory.of(baseRendered: baseRendered, headRendered: headRendered,
                                            deltas: [], pixelsChanged: 0, tolerance: options.tolerance)
            e.errors = errors.isEmpty ? nil : errors
            return e
        }
        func load(_ key: String, _ dir: URL, _ result: RenderResult?, fit: Bool = false) -> Bitmap? {
            guard result?.rendered == true else { return nil }
            switch Pipeline.load(dirs.png(dir, name), size: px, fit: fit) {
            case let .success(b): return b
            case let .failure(err): errors[key] = err.description; return nil
            }
        }
        let baseImage = load("base", dirs.base, r.base)
        let headImage = load("head", dirs.head, r.head)
        let webkit = load("webkit", dirs.webkit, r.webkitResult)
        let resvg = load("resvg", dirs.resvg, r.resvg, fit: session.resvg?.isPNG == false)
        let blur = Diff.blur(scale: options.scale)
        func pct(_ a: Bitmap?, _ b: Bitmap?) -> Diff? {
            guard let a, let b else { return nil }
            return Diff.compare(a, b, blur: blur)
        }

        let headWebKit = pct(webkit, headImage), headResvg = pct(resvg, headImage)
        e.base = pct(webkit, baseImage).map { $0.score * 100 }
        e.head = headWebKit.map { $0.score * 100 }
        e.baseResvg = pct(resvg, baseImage).map { $0.score * 100 }
        e.headResvg = headResvg.map { $0.score * 100 }
        e.webkitResvg = pct(webkit, resvg).map { $0.score * 100 }
        e.delta = e.base.flatMap { b in e.head.map { $0 - b } }
        e.deltaResvg = e.baseResvg.flatMap { b in e.headResvg.map { $0 - b } }
        let match = options.match
        func verdict(_ w: Double?, _ s: Double?) -> Verdict? {
            guard let w, let s, let wr = e.webkitResvg else { return nil }
            return Verdict(webkit: w / 100, resvg: s / 100, webkitResvg: wr / 100, match: match / 100)
        }
        e.baseVerdict = verdict(e.base, e.baseResvg)
        e.headVerdict = verdict(e.head, e.headResvg)

        var change: Diff?
        if let baseImage, let headImage {
            // Exact comparison: no blur, tiny threshold, so any real change shows.
            change = Diff.compare(baseImage, headImage, blur: 0, threshold: 2)
            e.pixelsChanged = change?.differing
        }
        e.category = CompareCategory.of(
            baseRendered: baseImage != nil, headRendered: headImage != nil,
            deltas: [e.delta, e.deltaResvg].compactMap { $0 }, pixelsChanged: e.pixelsChanged ?? 0, tolerance: options.tolerance
        )
        if e.category != .unchanged {
            try? headWebKit?.image.writePNG(to: dirs.diff.appendingPathComponent("\(name).webkit.png"))
            try? headResvg?.image.writePNG(to: dirs.diff.appendingPathComponent("\(name).resvg.png"))
            try? change?.image.writePNG(to: dirs.diff.appendingPathComponent("\(name).change.png"))
        }
        e.errors = errors.isEmpty ? nil : errors
        return e
    }

    // MARK: - Summary

    func printSummary(_ report: CompareReport) {
        let refs = [report.engine, report.resvg].compactMap { $0 }.joined(separator: " and ")
        print("\nReferences: \(refs) · \(report.os) · font smoothing \(report.fontSmoothing ? "on" : "off") · tolerance \(String(format: "%g", report.tolerance)) pts\n")
        let width = max(10, report.results.map(\.name.count).max() ?? 10)
        let hasResvg = report.resvg != nil

        func side(_ base: Double?, _ head: Double?, _ delta: Double?, baseStatus: String, headStatus: String) -> String {
            let b = base.map { String(format: "%6.2f%%", $0) } ?? (baseStatus == "failed" ? "failed" : "–").leftPadded(7)
            let h = head.map { String(format: "%6.2f%%", $0) } ?? (headStatus == "failed" ? "failed" : "–").leftPadded(7)
            let d = delta.map { String(format: "%+7.2f", $0) } ?? "       "
            return "\(b) → \(h) \(d)"
        }
        func line(_ e: CompareReport.Entry) -> String {
            var s = "  \(e.name.padded(width))  WebKit " + side(e.base, e.head, e.delta, baseStatus: e.baseStatus, headStatus: e.headStatus)
            if hasResvg {
                s += "   resvg " + side(e.baseResvg, e.headResvg, e.deltaResvg, baseStatus: e.baseStatus, headStatus: e.headStatus)
                if let b = e.baseVerdict, let h = e.headVerdict, b != h { s += "   \(b.label) → \(h.label)" }
            }
            if let px = e.pixelsChanged, px > 0 { s += "   \(px) px changed" }
            if e.category == .error || e.category == .regressed, let errors = e.errors {
                s += "   (" + errors.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "; ") + ")"
            }
            return s
        }

        let groups: [(CompareCategory, String, String)] = [
            (.regressed, "Regressed", "further from a reference, not closer to the other"),
            (.mixed, "Mixed", "closer to one reference, further from the other; not a failure, check by eye"),
            (.improved, "Improved", "closer to a reference"),
            (.changed, "Changed", "pixels differ, scores within tolerance"),
            (.error, "Errors", "no reference rendered"),
        ]
        func magnitude(_ e: CompareReport.Entry) -> Double { max(abs(e.delta ?? 100), abs(e.deltaResvg ?? 0)) }
        for (category, title, detail) in groups {
            let items = report.results.filter { $0.category == category }.sorted { magnitude($0) > magnitude($1) }
            guard !items.isEmpty else { continue }
            print("\(title) (\(items.count)) — \(detail)")
            items.forEach { print(line($0)) }
            print("")
        }
        let redrawn = report.results.filter { $0.redrawn != nil }
        if !redrawn.isEmpty {
            print("Redrawn (\(redrawn.count)) — WebKit's first draw was blank, scored from a later one")
            for e in redrawn { print("  \(e.name): \(e.redrawn!) \(e.redrawn == 1 ? "retry" : "retries")") }
            print("")
        }
        let unchanged = report.results.filter { $0.category == .unchanged }.count
        let regressed = report.results.filter { $0.category == .regressed }.count
        print("Unchanged: \(unchanged) of \(report.results.count)")
        print(regressed == 0 ? "Result: no regressions" : "Result: \(regressed) regression\(regressed == 1 ? "" : "s")")
    }
}
