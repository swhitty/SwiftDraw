import AppKit
import WebKit

/// Renders SVG data via an `<img>` element in a WKWebView and snapshots it.
@MainActor
final class WebKitRenderer: NSObject, WKNavigationDelegate {

    struct Snapshot {
        var image: CGImage
        var info: String
    }

    enum Failure: Error, CustomStringConvertible {
        case navigation(String)
        case decode(String)
        case snapshot(String)

        var description: String {
            switch self {
            case .navigation(let s): return "navigation: \(s)"
            case .decode(let s): return "decode: \(s)"
            case .snapshot(let s): return "snapshot: \(s)"
            }
        }
    }

    let webView: WKWebView
    let window: NSWindow?
    private var navigation: CheckedContinuation<Void, Error>?

    init(useWindow: Bool) {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 256, height: 256), configuration: config)
        if useWindow {
            let window = NSWindow(
                contentRect: CGRect(x: -20000, y: -20000, width: 256, height: 256),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = webView
            window.orderBack(nil)
            self.window = window
        } else {
            self.window = nil
        }
        super.init()
        webView.navigationDelegate = self
    }

    var backingScale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
    }

    func render(svg data: Data, size: CGSize) async throws -> Snapshot {
        let w = Int(size.width.rounded()), h = Int(size.height.rounded())
        if let window {
            window.setContentSize(CGSize(width: w, height: h))
        }
        webView.frame = CGRect(x: 0, y: 0, width: w, height: h)

        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>
        html,body{margin:0;padding:0;background:#fff;overflow:hidden}
        img{display:block}
        </style></head><body>
        <img id="i" width="\(w)" height="\(h)" src="data:image/svg+xml;base64,\(data.base64EncodedString())">
        </body></html>
        """
        trace("load start")
        try await load(html: html)
        trace("load finished")

        let result = try await webView.callAsyncJavaScript(
            """
            const i = document.getElementById('i');
            try { await i.decode(); } catch (e) { return 'decode-failed'; }
            // requestAnimationFrame never fires in an off-screen window; a short timeout lets layout settle.
            await new Promise(r => setTimeout(r, 30));
            return 'natural=' + i.naturalWidth + 'x' + i.naturalHeight;
            """,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
        let info = (result as? String) ?? "?"
        trace("js done \(info)")
        if info == "decode-failed" { throw Failure.decode("img.decode() rejected") }

        let config = WKSnapshotConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: w, height: h)
        config.afterScreenUpdates = true
        let image = try await webView.takeSnapshot(configuration: config)
        trace("snapshot done")
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw Failure.snapshot("no CGImage")
        }
        return Snapshot(image: cg, info: "\(info) snapshot=\(cg.width)x\(cg.height)")
    }

    private func load(html: String) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            navigation = c
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            self.navigation?.resume()
            self.navigation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated {
            self.navigation?.resume(throwing: Failure.navigation(error.localizedDescription))
            self.navigation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated {
            self.navigation?.resume(throwing: Failure.navigation(error.localizedDescription))
            self.navigation = nil
        }
    }

    nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        MainActor.assumeIsolated {
            self.navigation?.resume(throwing: Failure.navigation("web content process terminated"))
            self.navigation = nil
        }
    }
}

func trace(_ s: String) {
    if ProcessInfo.processInfo.environment["SVGREF_TRACE"] != nil {
        FileHandle.standardError.write(Data("[trace] \(s)\n".utf8))
    }
}
