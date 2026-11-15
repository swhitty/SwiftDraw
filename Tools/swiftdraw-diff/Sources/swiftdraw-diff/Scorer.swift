import AppKit
import WebKit

/// Loads a generated report page in a hidden WKWebView, lets the page's own
/// JavaScript diff every SVG against WebKit's rendering, then reads the results
/// back. The window is never shown; WebKit only needs a GUI login session.
@MainActor
enum Scorer {

    struct Score: Codable {
        var name: String
        var status: String
        /// Fraction of ink pixels that differ from WebKit's rendering, 0...1.
        /// nil when the page could not compare (e.g. SwiftDraw failed to parse).
        var score: Double?
        var error: String?
        /// Images that first drew blank in the scoring page and were redrawn, e.g. "swiftdraw png: 1 retry".
        var redrawn: [String]?
    }

    struct Report: Codable {
        var engine: String
        var os: String
        var generated: Date
        var results: [Score]
    }

    struct PageResult {
        var engine: String
        var os: String
        var rows: [[String: Any]]
    }

    enum Failure: Error, CustomStringConvertible {
        case timeout(done: Int, total: Int)
        case unexpected(String)

        var description: String {
            switch self {
            case let .timeout(done, total): return "timed out scoring (\(done)/\(total) done)"
            case let .unexpected(s): return s
            }
        }
    }

    /// Scores the eyeball report (index.html written by `writeEyeball`).
    static func score(report url: URL, timeout: TimeInterval = 600, progress: (Int, Int) -> Void) async throws -> Report {
        let page = try await evaluate(
            page: url,
            rowsExpression: "ROWS.map(r => ({ name: r.name, status: r.status, score: r.score, error: r.error ?? null, redrawn: r.redrawn ?? null }))",
            timeout: timeout,
            progress: progress
        )
        let results = page.rows.map { row -> Score in
            let status = row["status"] as? String ?? ""
            // The page uses score 1 as a sort key for files SwiftDraw could not parse.
            let score = status == "swiftdraw-nil" ? nil : row["score"] as? Double
            return Score(name: row["name"] as? String ?? "?", status: status, score: score, error: row["error"] as? String,
                         redrawn: row["redrawn"] as? [String])
        }
        return Report(engine: page.engine, os: page.os, generated: Date(), results: results)
    }

    /// Loads `page`, waits for `window.EYEBALL_DONE`, then returns the JSON
    /// produced by `rowsExpression` (a JS expression evaluating to an array).
    /// Progress is reported from the page's global `ROWS[].score`.
    static func evaluate(page url: URL, rowsExpression: String, timeout: TimeInterval = 600, progress: (Int, Int) -> Void) async throws -> PageResult {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 900))
        // Hosting in a window (never ordered on screen) keeps WebKit from treating the page as detached.
        let window = NSWindow(contentRect: webView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        defer { window.contentView = nil }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

        let deadline = Date().addingTimeInterval(timeout)
        var lastDone = -1, finished = false, done = 0, total = 0
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 250_000_000)
            guard let json = try? await webView.evaluateJavaScript(
                "typeof ROWS === 'undefined' ? null : JSON.stringify({finished: window.EYEBALL_DONE === true, done: ROWS.filter(r => r.score !== null && r.score !== undefined).length, total: ROWS.length})"
            ) as? String,
                  let state = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
                continue
            }
            done = state["done"] as? Int ?? 0
            total = state["total"] as? Int ?? 0
            if done != lastDone { progress(done, total); lastDone = done }
            if state["finished"] as? Bool == true { finished = true; break }
        }
        guard finished else { throw Failure.timeout(done: done, total: total) }

        guard let json = try await webView.evaluateJavaScript(
            "JSON.stringify({ ua: navigator.userAgent, rows: \(rowsExpression) })"
        ) as? String,
              let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let rows = object["rows"] as? [[String: Any]] else {
            throw Failure.unexpected("could not read results from page")
        }
        return PageResult(
            engine: webKitVersion(userAgent: object["ua"] as? String),
            os: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            rows: rows
        )
    }

    private static func webKitVersion(userAgent: String?) -> String {
        let bundle = Bundle(identifier: "com.apple.WebKit")
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return "WebKit \(version ?? userAgent ?? "unknown")"
    }
}

/// Prints a progress counter on stderr when it's a terminal.
func progressPrinter(_ label: String) -> (Int, Int) -> Void {
    let isTTY = isatty(STDERR_FILENO) != 0
    return { done, total in
        guard isTTY else { return }
        let line = done >= total ? "\r\u{1B}[K" : "\r\(label)… \(done)/\(total)"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
