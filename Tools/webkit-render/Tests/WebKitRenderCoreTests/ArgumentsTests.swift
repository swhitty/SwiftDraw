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
        ["in.svg", "out.png"],                                  // no --size
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
