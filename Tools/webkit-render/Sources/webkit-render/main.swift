import AppKit
import CoreGraphics
import WebKitRenderCore

setvbuf(stdout, nil, _IOLBF, 0)

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("webkit-render: \(message)\n".utf8))
    exit(code)
}

let arguments: Arguments
do {
    arguments = try Arguments.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    fail("\(error)\n\n\(Arguments.usage)", code: 2)
}

switch arguments.mode {
case .help:
    print(Arguments.usage)
    exit(0)
case .version:
    print(WebKitRenderer.webKitVersion)
    exit(0)
case .single, .batch:
    break
}

// WebKit needs the window server: without a logged-in GUI session (e.g. over ssh before anyone
// has logged in at the console) WKWebView hangs or crashes instead of failing.
guard CGSessionCopyCurrentDictionary() != nil else {
    fail("no GUI login session; WebKit needs a logged-in macOS desktop session (run from Terminal on a logged-in Mac, not a bare ssh session)")
}

@MainActor
func run() async throws -> Int32 {
    let renderer = WebKitRenderer()
    switch arguments.mode {
    case let .single(input, output, size):
        let data: Data
        do { data = try Data(contentsOf: input) } catch { fail("cannot read \(input.path): \(error.localizedDescription)") }
        let (w, h) = size.pixels(scale: arguments.scale)
        let svg = ReferenceSVG.prepare(data, fontSmoothing: arguments.fontSmoothing)
        let result = try await renderer.render(svg: svg, width: w, height: h)
        try result.png.write(to: output)
        return 0

    case let .batch(jobsURL, out):
        let jobs: [Job]
        do { jobs = try Job.decode(Data(contentsOf: jobsURL)) } catch { fail("cannot read \(jobsURL.path): \(error)") }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let isTTY = isatty(STDERR_FILENO) != 0
        var manifest: [ManifestEntry] = []
        for (index, job) in jobs.enumerated() {
            if isTTY { FileHandle.standardError.write(Data("\rWebKit… \(index + 1)/\(jobs.count)\u{1B}[K".utf8)) }
            let (w, h) = job.size.pixels(scale: arguments.scale)
            let png = out.appendingPathComponent("\(job.name).png")
            try? FileManager.default.removeItem(at: png) // never leave a stale image for a failed job
            do {
                let data = try Data(contentsOf: job.svgURL(relativeTo: jobsURL))
                let svg = ReferenceSVG.prepare(data, fontSmoothing: arguments.fontSmoothing)
                let result = try await renderer.render(svg: svg, width: w, height: h)
                try result.png.write(to: png)
                manifest.append(ManifestEntry(name: job.name, status: .rendered,
                                              redrawn: result.redrawn > 0 ? result.redrawn : nil,
                                              width: w, height: h))
            } catch {
                manifest.append(ManifestEntry(name: job.name, status: .failed, error: "\(error)", width: w, height: h))
            }
        }
        if isTTY { FileHandle.standardError.write(Data("\r\u{1B}[K".utf8)) }
        try ManifestEntry.encode(manifest).write(to: out.appendingPathComponent("manifest.json"))

        let failed = manifest.filter { $0.status == .failed }.count
        print("Rendered \(manifest.count - failed)/\(manifest.count) → \(out.path)")
        // Per-file failures are recorded in the manifest; they are results, not tool errors.
        return 0

    case .help, .version:
        return 0
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
Task { @MainActor in
    do {
        exit(try await run())
    } catch {
        fail("\(error)")
    }
}
app.run()
