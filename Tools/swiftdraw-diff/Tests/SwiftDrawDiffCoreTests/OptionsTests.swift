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
        #expect(o.resvg == nil)
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
        #expect(o.resvg == .cli)
        #expect(o.tolerance == 1)
        #expect(o.inputs.count == 2)
    }

    @Test
    func resvgSources() throws {
        #expect(try Self.parse(["--resvg-png", "sibling", "a.svg"]).resvg == .sibling)
        #expect(try Self.parse(["--resvg-png", "pngs", "a.svg"]).resvg == .directory(URL(fileURLWithPath: "pngs")))
        let o = try Self.parse(["--resvg-path", "/opt/resvg", "a.svg"])
        #expect(o.resvg == .cli)
        #expect(o.resvgPath == URL(fileURLWithPath: "/opt/resvg"))
    }

    @Test
    func rendererPaths() throws {
        let o = try Self.parse(["--swiftdraw-path", "/bin/sd", "--webkit-render-path", "/bin/wr", "--no-cache", "a.svg"])
        #expect(o.swiftdrawPath == URL(fileURLWithPath: "/bin/sd"))
        #expect(o.webkitRenderPath == URL(fileURLWithPath: "/bin/wr"))
        #expect(!o.useCache)
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
        ["--resvg-png", "sibling", "--resvg-path", "/opt/resvg", "a.svg"],
        ["a.svg", "--head"],                            // missing value
    ])
    func rejects(_ args: [String]) {
        #expect(throws: Options.Error.self) {
            try Options.parse(args, fileExists: { !["missing.svg", "help", "score"].contains($0) })
        }
    }

    @Test
    func directoriesListTheirSVGsSorted() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("OptionsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("nested"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["b.svg", "a.SVG", "c.png", "nested/d.svg"] {
            try Data().write(to: dir.appendingPathComponent(name))
        }
        var o = Options()
        o.inputs = [dir]
        #expect(o.svgFiles().map(\.lastPathComponent) == ["a.SVG", "b.svg"])
    }
}
