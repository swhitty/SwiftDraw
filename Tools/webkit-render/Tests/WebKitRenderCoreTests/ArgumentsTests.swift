import Foundation
import Testing
@testable import WebKitRenderCore

struct ArgumentsTests {

    @Test
    func singleFile() throws {
        let args = try Arguments.parse(["in.svg", "out.png", "--size", "64x48"])
        #expect(args.mode == .single(input: URL(fileURLWithPath: "in.svg"), output: URL(fileURLWithPath: "out.png"),
                                     size: Size(width: 64, height: 48)))
        #expect(args.scale == 2)
        #expect(args.fontSmoothing == false)
    }

    @Test
    func optionsAnywhere() throws {
        let args = try Arguments.parse(["--scale", "3", "--font-smoothing", "in.svg", "--size", "10.5x20", "out.png"])
        #expect(args.mode == .single(input: URL(fileURLWithPath: "in.svg"), output: URL(fileURLWithPath: "out.png"),
                                     size: Size(width: 10.5, height: 20)))
        #expect(args.scale == 3)
        #expect(args.fontSmoothing)
    }

    @Test
    func batch() throws {
        let args = try Arguments.parse(["--jobs", "jobs.json", "--out", "dir", "--scale", "1"])
        #expect(args.mode == .batch(jobs: URL(fileURLWithPath: "jobs.json"), out: URL(fileURLWithPath: "dir")))
        #expect(args.scale == 1)
    }

    @Test
    func version() throws {
        #expect(try Arguments.parse(["--version"]).mode == .version)
        #expect(try Arguments.parse(["--help"]).mode == .help)
    }

    @Test(arguments: [
        ["in.svg", "out.png", "--max", "0"],
        ["in.svg", "--size", "10x10"],                          // no output
        ["a.svg", "b.svg", "c.png", "--size", "10x10"],         // too many paths
        ["in.svg", "out.png", "--size"],                        // missing value
        ["in.svg", "out.png", "--size", "10"],                  // not WxH
        ["in.svg", "out.png", "--size", "0x10"],                // zero
        ["in.svg", "out.png", "--size", "10x10", "--scale", "-1"],
        ["in.svg", "out.png", "--size", "10x10", "--out", "dir"],
        ["in.svg", "out.png", "--size", "10x10", "--bogus"],
        ["--jobs", "jobs.json"],                                // no --out
        ["--jobs", "jobs.json", "--out", "dir", "in.svg"],
        ["--jobs", "jobs.json", "--out", "dir", "--size", "1x1"],
        [],
    ])
    func rejects(_ args: [String]) {
        #expect(throws: Arguments.Error.self) { try Arguments.parse(args) }
    }

    @Test
    func naturalSizeAndMax() throws {
        let args = try Arguments.parse(["in.svg", "out.png", "--max", "256"])
        #expect(args.mode == .single(input: URL(fileURLWithPath: "in.svg"), output: URL(fileURLWithPath: "out.png"), size: nil))
        #expect(args.maxDimension == 256)
        #expect(try Arguments.parse(["--jobs", "j.json", "--out", "d"]).maxDimension == 1024)
    }

    @Test(arguments: [
        (Size(width: 64, height: 48), 1024.0 as Double, Size(width: 64, height: 48)),
        (Size(width: 10.5, height: 20.4), 1024.0, Size(width: 11, height: 20)),       // whole points
        (Size(width: 2048, height: 1024), 1024.0, Size(width: 1024, height: 512)),     // clamped
        (Size(width: 3000, height: 1), 1024.0, Size(width: 1024, height: 1)),          // at least 1
        (Size(width: 0.2, height: 0.2), 1024.0, Size(width: 1, height: 1)),
    ])
    func layoutSize(_ natural: Size, _ max: Double, _ expected: Size) {
        #expect(Size.layout(natural: natural, max: max) == expected)
    }

    @Test(arguments: [
        ("64x48", Size(width: 64, height: 48)),
        ("64X48", Size(width: 64, height: 48)),
        ("0.5x1e2", Size(width: 0.5, height: 100)),
    ])
    func parsesSize(_ text: String, _ size: Size) {
        #expect(Size(text) == size)
    }

    @Test(arguments: ["", "x", "10x", "x10", "10x10x10", "-1x5", "ax5", "infx5", "nanx5"])
    func rejectsSize(_ text: String) {
        #expect(Size(text) == nil)
    }

    @Test
    func pixelsRound() {
        #expect(Size(width: 50.3, height: 20).pixels(scale: 2) == (101, 40))
        #expect(Size(width: 10.25, height: 10.75).pixels(scale: 1) == (10, 11))
        #expect(Size(width: 0.1, height: 0.1).pixels(scale: 1) == (1, 1))
    }
}
