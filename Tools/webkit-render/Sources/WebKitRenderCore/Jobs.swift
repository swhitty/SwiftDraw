import Foundation

/// One entry of `jobs.json`: render `svg` at `width`×`height` points to `<out>/<name>.png`.
public struct Job: Codable, Equatable, Sendable {
    public var name: String
    /// Path to the SVG; relative paths resolve against the jobs file's directory.
    public var svg: String
    public var width: Double
    public var height: Double

    public init(name: String, svg: String, width: Double, height: Double) {
        self.name = name
        self.svg = svg
        self.width = width
        self.height = height
    }

    public var size: Size { Size(width: width, height: height) }

    public func svgURL(relativeTo jobsFile: URL) -> URL {
        URL(fileURLWithPath: svg, relativeTo: jobsFile.deletingLastPathComponent()).standardizedFileURL
    }

    /// Reads and validates a jobs file.
    public static func decode(_ data: Data) throws -> [Job] {
        let jobs = try JSONDecoder().decode([Job].self, from: data)
        var names = Set<String>()
        for job in jobs {
            guard !job.name.isEmpty, !job.name.contains("/"), job.name != ".", job.name != ".." else {
                throw Invalid("job name '\(job.name)' must be a plain file name")
            }
            guard names.insert(job.name).inserted else { throw Invalid("duplicate job name '\(job.name)'") }
            guard job.width > 0, job.height > 0, job.width.isFinite, job.height.isFinite else {
                throw Invalid("job '\(job.name)' needs a positive width and height")
            }
        }
        return jobs
    }

    public struct Invalid: Error, CustomStringConvertible {
        public var description: String
        init(_ description: String) { self.description = description }
    }
}

/// One entry of `manifest.json`.
public struct ManifestEntry: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case rendered
        case failed
    }

    public var name: String
    public var status: Status
    public var error: String?
    /// How many times the image was redrawn because it first drew blank (a WebKit timing glitch).
    /// Only set when a redraw recovered a non-blank image.
    public var redrawn: Int?
    /// PNG width in pixels.
    public var width: Int
    /// PNG height in pixels.
    public var height: Int

    public init(name: String, status: Status, error: String? = nil, redrawn: Int? = nil, width: Int, height: Int) {
        self.name = name
        self.status = status
        self.error = error
        self.redrawn = redrawn
        self.width = width
        self.height = height
    }

    public static func encode(_ entries: [ManifestEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(entries)
    }
}
