import Foundation
import Testing
@testable import WebKitRenderCore

struct JobsTests {

    @Test
    func decodesJobs() throws {
        let json =
            #"[{"name":"a","svg":"svg/a.svg","width":64,"height":32.5},{"name":"b","svg":"/abs/b.svg","width":1,"height":2}]"#
        let jobs = try Job.decode(Data(json.utf8))
        #expect(
            jobs == [
                Job(name: "a", svg: "svg/a.svg", width: 64, height: 32.5),
                Job(name: "b", svg: "/abs/b.svg", width: 1, height: 2),
            ]
        )
    }

    @Test
    func jobsWithoutSizeUseNaturalSize() throws {
        let jobs = try Job.decode(Data(#"[{"name":"a","svg":"a.svg"}]"#.utf8))
        #expect(jobs == [Job(name: "a", svg: "a.svg")])
        #expect(jobs[0].size == nil)
        #expect(Job(name: "b", svg: "b.svg", width: 3, height: 4).size == Size(width: 3, height: 4))
    }

    @Test
    func resolvesSVGAgainstJobsDirectory() {
        let jobsFile = URL(fileURLWithPath: "/tmp/run/jobs.json")
        #expect(
            Job(name: "a", svg: "svg/a.svg", width: 1, height: 1).svgURL(relativeTo: jobsFile).path
                == "/tmp/run/svg/a.svg"
        )
        #expect(
            Job(name: "b", svg: "/abs/b.svg", width: 1, height: 1).svgURL(relativeTo: jobsFile).path == "/abs/b.svg"
        )
    }

    @Test(arguments: [
        #"[{"name":"a","svg":"a.svg","width":1}]"#,  // missing height
        #"[{"name":"","svg":"a.svg","width":1,"height":1}]"#,  // empty name
        #"[{"name":"x/a","svg":"a.svg","width":1,"height":1}]"#,  // path in name
        #"[{"name":"..","svg":"a.svg","width":1,"height":1}]"#,
        #"[{"name":"a","svg":"a.svg","width":0,"height":1}]"#,  // zero size
        // duplicate
        #"[{"name":"a","svg":"a.svg","width":1,"height":1},{"name":"a","svg":"b.svg","width":1,"height":1}]"#,
        #"{"name":"a"}"#,
    ])
    func rejectsInvalidJobs(_ json: String) {
        #expect(throws: (any Error).self) { try Job.decode(Data(json.utf8)) }
    }

    @Test
    func encodesManifest() throws {
        let entries = [
            ManifestEntry(name: "a", status: .rendered, width: 128, height: 64),
            ManifestEntry(name: "b", status: .rendered, redrawn: 2, width: 10, height: 10),
            ManifestEntry(name: "c", status: .failed, error: "WebKit could not load the SVG", width: 2, height: 2),
            ManifestEntry(
                name: "d",
                status: .rendered,
                width: 22,
                height: 40,
                layout: Size(width: 11, height: 20),
                natural: Size(width: 10.5, height: 20.4)
            ),
        ]
        let data = try ManifestEntry.encode(entries)
        let objects = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        #expect(objects[0].keys.sorted() == ["height", "name", "status", "width"])
        #expect(objects[0]["status"] as? String == "rendered")
        #expect(objects[1]["redrawn"] as? Int == 2)
        #expect(objects[2]["status"] as? String == "failed")
        #expect(objects[2]["error"] as? String == "WebKit could not load the SVG")
        #expect(objects[3]["layoutWidth"] as? Double == 11)
        #expect(objects[3]["layoutHeight"] as? Double == 20)
        #expect(objects[3]["naturalWidth"] as? Double == 10.5)
        #expect(objects[3]["naturalHeight"] as? Double == 20.4)

        #expect(try JSONDecoder().decode([ManifestEntry].self, from: data) == entries)
    }
}
