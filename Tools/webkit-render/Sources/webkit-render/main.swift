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

// WebKit needs the window server, so the user must be logged in at the Mac. ssh works while they
// are; with nobody logged in (login window, after logging out) fail clearly rather than hang.
guard CGSessionCopyCurrentDictionary() != nil else {
    fail("no GUI login session; WebKit needs the user logged in at the Mac (ssh works once they are)")
}

/// The requested size, or the SVG's natural size clamped to --max and rounded to whole points.
@MainActor
func layoutSize(_ requested: Size?, svg: Data, renderer: WebKitRenderer) async throws -> (layout: Size, natural: Size?) {
    if let requested { return (requested, nil) }
    let natural = try await renderer.measure(svg: svg)
    return (Size.layout(natural: natural, max: arguments.maxDimension), natural)
}

@MainActor
func run() async throws -> Int32 {
    let renderer = WebKitRenderer()
    switch arguments.mode {
    case let .single(input, output, size):
        let data: Data
        do { data = try Data(contentsOf: input) } catch { fail("cannot read \(input.path): \(error.localizedDescription)") }
        let svg = ReferenceSVG.prepare(data, fontSmoothing: arguments.fontSmoothing)
        let layout = try await layoutSize(size, svg: svg, renderer: renderer).layout
        let (w, h) = layout.pixels(scale: arguments.scale)
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
            let png = out.appendingPathComponent("\(job.name).png")
            try? FileManager.default.removeItem(at: png) // never leave a stale image for a failed job
            var layout = job.size, natural: Size?
            do {
                let data = try Data(contentsOf: job.svgURL(relativeTo: jobsURL))
                let svg = ReferenceSVG.prepare(data, fontSmoothing: arguments.fontSmoothing)
                let sized = try await layoutSize(job.size, svg: svg, renderer: renderer)
                layout = sized.layout
                natural = sized.natural
                let (w, h) = sized.layout.pixels(scale: arguments.scale)
                let result = try await renderer.render(svg: svg, width: w, height: h)
                try result.png.write(to: png)
                manifest.append(ManifestEntry(name: job.name, status: .rendered,
                                              redrawn: result.redrawn > 0 ? result.redrawn : nil,
                                              width: w, height: h, layout: sized.layout, natural: sized.natural))
            } catch {
                let (w, h) = layout?.pixels(scale: arguments.scale) ?? (0, 0)
                manifest.append(ManifestEntry(name: job.name, status: .failed, error: "\(error)", width: w, height: h,
                                              layout: layout, natural: natural))
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
