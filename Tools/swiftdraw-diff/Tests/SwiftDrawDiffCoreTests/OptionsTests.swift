import Foundation
import Testing
@testable import SwiftDrawDiffCore

struct OptionsTests {

    static func parse(_ args: [String]) throws -> Options {
        try Options.parse(args, fileExists: { !$0.hasPrefix("missing") })
    }

    @Test
    func defaults() throws {
        let o = try Self.parse(["Samples.bundle"])
        #expect(o.command == .report)
        #expect(o.inputs == [URL(fileURLWithPath: "Samples.bundle")])
        #expect(!o.usesResvg)
        #expect(o.scale == 2)
        #expect(o.match == 1)
        #expect(o.tolerance == 0.5)
        #expect(o.useCache)
    }

    @Test
    func compare() throws {
        let o = try Self.parse(["compare", "--base", "0.30.0", "--head", "main", "--resvg", "--tolerance", "1", "a.svg", "b.svg"])
        #expect(o.command == .compare)
        #expect(o.base == "0.30.0")
        #expect(o.head == "main")
        #expect(o.resvgCLI)
        #expect(o.resvgPNG == nil)
        #expect(o.tolerance == 1)
        #expect(o.inputs.count == 2)
    }

    @Test
    func resvgSources() throws {
        let sibling = try Self.parse(["--resvg-png", "sibling", "a.svg"])
        #expect(sibling.resvgPNG == .sibling)
        #expect(!sibling.resvgCLI)
        #expect(sibling.usesResvg)
        #expect(try Self.parse(["--resvg-png", "pngs", "a.svg"]).resvgPNG == .directory(URL(fileURLWithPath: "pngs")))
        let o = try Self.parse(["--resvg-path", "/opt/resvg", "a.svg"])
        #expect(o.resvgCLI)
        #expect(o.resvgPath == URL(fileURLWithPath: "/opt/resvg"))
    }

    @Test(arguments: [
        ["--resvg", "--resvg-png", "sibling", "a.svg"],
        ["--resvg-png", "sibling", "--resvg", "a.svg"],
        ["--resvg-png", "sibling", "--resvg-path", "/opt/resvg", "a.svg"],
    ])
    func resvgPNGWithCLIFallback(_ args: [String]) throws {
        let o = try Self.parse(args)
        #expect(o.resvgPNG == .sibling)
        #expect(o.resvgCLI)
    }

    @Test
    func rendererPaths() throws {
        let o = try Self.parse(["--swiftdraw-path", "/bin/sd", "--webkit-render-path", "/bin/wr", "--no-cache", "a.svg"])
        #expect(o.swiftdrawPath == URL(fileURLWithPath: "/bin/sd"))
        #expect(o.webkitRenderPath == URL(fileURLWithPath: "/bin/wr"))
        #expect(!o.useCache)
    }

    @Test(arguments: [
        // hasPNGs, hasCLI, text, expected
        (true, true, false, true),      // PNG when usable, the CLI otherwise
        (true, true, true, false),      // text always goes to the CLI: the PNGs use other fonts
        (true, false, true, true),      // no CLI: text is compared against the PNG, and the summary says so
        (false, true, false, false),
        (false, true, true, false),
    ])
    func resvgPNGOrCLI(hasPNGs: Bool, hasCLI: Bool, text: Bool, expected: Bool) {
        #expect(Options.prefersResvgPNG(hasPNGs: hasPNGs, hasCLI: hasCLI, text: text) == expected)
    }

    @Test(arguments: [
        [],                                             // no inputs
        ["missing.svg"],                                // no such file (and not a command)
        ["help", "score"],                              // unknown subcommands are not files
        ["--scale", "1.5", "a.svg"],                    // swiftdrawcli takes 1x, 2x or 3x
        ["--scale", "4", "a.svg"],
        ["--match", "0", "a.svg"],
        ["--tolerance", "-1", "a.svg"],
        ["--bogus", "a.svg"],
        ["--base", "main", "a.svg"],                    // --base is for compare
        ["--head", "main", "--swiftdraw-path", "/bin/sd", "a.svg"],
        ["a.svg", "--head"],                            // missing value
    ])
    func rejects(_ args: [String]) {
        #expect(throws: Options.Error.self) {
            try Options.parse(args, fileExists: { !["missing.svg", "help", "score"].contains($0) })
        }
    }

    @Test
    func directoriesListTheirSVGsRecursivelyByRelativePath() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("OptionsTests-\(UUID().uuidString)")
        let fm = FileManager.default
        for sub in ["text/text-anchor", "a", ".hidden"] {
            try fm.createDirectory(at: dir.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        defer { try? fm.removeItem(at: dir) }
        for name in ["b.svg", "a.SVG", "c.png", "text/text-anchor/simple-case.svg", "text/text-anchor/simple-case.png",
                     "a/z.svg", ".hidden/x.svg", ".dot.svg"] {
            try Data().write(to: dir.appendingPathComponent(name))
        }
        var o = Options()
        o.inputs = [dir, dir.appendingPathComponent("b.svg")]
        let files = o.svgFiles()
        #expect(files.map(\.name) == ["a", "a/z", "b", "text/text-anchor/simple-case", "b"])
        #expect(files[3].url.lastPathComponent == "simple-case.svg")
    }
}
