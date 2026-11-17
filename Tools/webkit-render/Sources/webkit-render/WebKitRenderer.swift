import AppKit
import WebKit
import WebKitRenderCore

/// Renders SVGs to PNGs in one hidden WKWebView.
///
/// Each SVG is loaded as a data: URI into an `<img>` and drawn onto a white canvas at the
/// requested pixel size, as swiftdraw-diff's in-page scorer does (`drawChecked`). A draw that
/// comes out entirely white is retried from a fresh load, because WebKit sometimes paints
/// nothing straight after load under load. The canvas is exported with `toBlob('image/png')`.
@MainActor
final class WebKitRenderer: NSObject, WKNavigationDelegate {

    struct Output {
        var png: Data
        /// Retries that recovered a non-blank image; 0 when the first draw was used.
        var redrawn: Int
    }

    struct Failure: Error, CustomStringConvertible {
        var description: String
    }

    private let webView: WKWebView
    private let window: NSWindow
    private var navigation: CheckedContinuation<Void, any Error>?
    private var isLoaded = false

    /// Per-image limit, enforced inside the page.
    var timeout: TimeInterval = 30

    override init() {
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        // Hosting in a window (never ordered on screen) keeps WebKit from treating the page as detached.
        self.window = NSWindow(contentRect: webView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        super.init()
        webView.navigationDelegate = self
    }

    /// The WebKit framework's bundle version, e.g. `21622.1.22.11.15`.
    static var webKitVersion: String {
        let bundle = Bundle(for: WKWebView.self)
        return bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    /// The SVG's natural size in points (`naturalWidth`/`naturalHeight` of an `<img>`).
    func measure(svg: Data) async throws -> WebKitRenderCore.Size {
        let result = try await call("return await measureSVG(src, timeout);", ["src": Self.dataURI(svg)])
        guard let object = result as? [String: Any],
              let w = (object["w"] as? NSNumber)?.doubleValue,
              let h = (object["h"] as? NSNumber)?.doubleValue else {
            throw Failure(description: "page returned no size")
        }
        guard w > 0, h > 0 else { throw Failure(description: "WebKit reports no natural size (\(w)×\(h))") }
        return WebKitRenderCore.Size(width: w, height: h)
    }

    func render(svg: Data, width: Int, height: Int) async throws -> Output {
        let result = try await call("return await renderSVG(src, w, h, timeout);",
                                    ["src": Self.dataURI(svg), "w": width, "h": height])
        guard let object = result as? [String: Any],
              let base64 = object["png"] as? String,
              let png = Data(base64Encoded: base64) else {
            throw Failure(description: "page returned no PNG")
        }
        return Output(png: png, redrawn: (object["redrawn"] as? Int) ?? 0)
    }

    private static func dataURI(_ svg: Data) -> String {
        "data:image/svg+xml;base64," + svg.base64EncodedString()
    }

    private func call(_ body: String, _ arguments: [String: Any]) async throws -> Any? {
        if !isLoaded {
            try await load()
            isLoaded = true
        }
        var arguments = arguments
        arguments["timeout"] = Int(timeout * 1000)
        do {
            return try await webView.callAsyncJavaScript(body, arguments: arguments, in: nil, contentWorld: .page)
        } catch {
            throw Failure(description: Self.message(for: error))
        }
    }

    private static func message(for error: any Error) -> String {
        let info = (error as NSError).userInfo
        if let message = info["WKJavaScriptExceptionMessage"] as? String {
            return message.replacingOccurrences(of: "Error: ", with: "")
        }
        return error.localizedDescription
    }

    private func load() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, any Error>) in
            navigation = c
            webView.loadHTMLString(Self.page, baseURL: nil)
        }
    }

    private func finishNavigation(_ error: any Error?) {
        if let error { navigation?.resume(throwing: error) } else { navigation?.resume() }
        navigation = nil
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { finishNavigation(nil) }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        MainActor.assumeIsolated { finishNavigation(Failure(description: "page load failed: \(error.localizedDescription)")) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        MainActor.assumeIsolated { finishNavigation(Failure(description: "page load failed: \(error.localizedDescription)")) }
    }

    nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        MainActor.assumeIsolated {
            // The next render reloads the page in a fresh web content process.
            isLoaded = false
            finishNavigation(Failure(description: "web content process terminated"))
        }
    }

    /// The host page. Images are data: URIs, so the canvas is never tainted.
    static let page = #"""
    <!doctype html>
    <html><head><meta charset="utf-8"></head><body>
    <script>
    function loadImage(src) {
      return new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => img.decode().then(() => resolve(img), () => resolve(img));
        img.onerror = () => reject(new Error('WebKit could not load the SVG'));
        img.src = src;
      });
    }

    function draw(img, w, h) {
      const c = document.createElement('canvas');
      c.width = w; c.height = h;
      const ctx = c.getContext('2d', { alpha: false, colorSpace: 'srgb' });
      ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, w, h);
      ctx.drawImage(img, 0, 0, w, h);
      return c;
    }

    function isBlank(c) {
      const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
      for (let i = 0; i < d.length; i += 4) if (d[i] < 250 || d[i + 1] < 250 || d[i + 2] < 250) return false;
      return true;
    }

    const REDRAW_DELAYS = [100, 400, 1000]; // ms; at most three extra attempts

    // As drawChecked in swiftdraw-diff: a draw that comes out entirely white is retried from a
    // fresh load. redrawn counts retries only when one recovers a non-blank image, so an SVG
    // that really is blank costs a little time but still renders (blank).
    async function drawChecked(src, w, h) {
      let canvas = draw(await loadImage(src), w, h);
      let attempts = 0;
      for (const delay of REDRAW_DELAYS) {
        if (!isBlank(canvas)) break;
        await new Promise(resolve => setTimeout(resolve, delay));
        canvas = draw(await loadImage(src), w, h);
        attempts++;
      }
      const redrawn = attempts > 0 && !isBlank(canvas) ? attempts : 0;
      return { canvas, redrawn };
    }

    async function exportPNG(canvas) {
      const blob = await new Promise((resolve, reject) =>
        canvas.toBlob(b => b ? resolve(b) : reject(new Error('canvas.toBlob failed')), 'image/png'));
      const url = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.onerror = () => reject(new Error('could not read PNG blob'));
        reader.readAsDataURL(blob);
      });
      return url.slice(url.indexOf(',') + 1);
    }

    function withTimeout(work, timeout) {
      const limit = new Promise((_, reject) =>
        setTimeout(() => reject(new Error(`timed out after ${timeout} ms`)), timeout));
      return Promise.race([work, limit]);
    }

    // The <img>'s natural size, as a browser lays it out without width or height attributes. For an
    // SVG without an absolute width and height this is the HTML default object size (300×150,
    // fitted to the viewBox's aspect ratio). naturalWidth/naturalHeight are whole numbers (300×90.87
    // reports 300×90), so the image is laid out in a box naturalWidth wide and measured: that keeps
    // fractions, and an SVG without an intrinsic width fills the box rather than the window.
    async function measureSVG(src, timeout) {
      const img = await withTimeout(loadImage(src), timeout);
      const box = document.createElement('div');
      box.style.cssText = `position:absolute; left:0; top:0; width:${img.naturalWidth}px`;
      img.style.display = 'block';
      box.appendChild(img);
      document.body.appendChild(box);
      const r = img.getBoundingClientRect();
      box.remove();
      return { w: r.width, h: r.height };
    }

    async function renderSVG(src, w, h, timeout) {
      const work = (async () => {
        const { canvas, redrawn } = await drawChecked(src, w, h);
        return { png: await exportPNG(canvas), redrawn };
      })();
      return withTimeout(work, timeout);
    }
    </script>
    </body></html>
    """#
}
