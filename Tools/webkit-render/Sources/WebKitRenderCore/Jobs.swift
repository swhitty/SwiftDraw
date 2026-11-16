public import Foundation

/// One entry of `jobs.json`: render `svg` at `width`×`height` points to `<out>/<name>.png`.
/// Without a size the SVG is laid out at its natural size (see `Size.layout(natural:max:)`).
public struct Job: Codable, Equatable, Sendable {
    public var name: String
    /// Path to the SVG; relative paths resolve against the jobs file's directory.
    public var svg: String
    public var width: Double?
    public var height: Double?

    public init(name: String, svg: String, width: Double? = nil, height: Double? = nil) {
        self.name = name
        self.svg = svg
        self.width = width
        self.height = height
    }

    /// The requested size in points; nil to use the SVG's natural size.
    public var size: Size? {
        guard let width, let height else { return nil }
        return Size(width: width, height: height)
    }

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
            switch (job.width, job.height) {
            case (nil, nil):
                break
            case let (w?, h?) where w > 0 && h > 0 && w.isFinite && h.isFinite:
                break
            default:
                throw Invalid("job '\(job.name)' needs a positive width and height, or neither")
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
    /// PNG width in pixels; 0 when the SVG failed before a size was known.
    public var width: Int
    /// PNG height in pixels; 0 when the SVG failed before a size was known.
    public var height: Int
    /// The size the SVG was laid out at, in points.
    public var layoutWidth: Double?
    public var layoutHeight: Double?
    /// The SVG's natural size as WebKit reports it (`naturalWidth`/`naturalHeight`), in points.
    /// Only set for jobs without a size.
    public var naturalWidth: Double?
    public var naturalHeight: Double?

    public init(name: String, status: Status, error: String? = nil, redrawn: Int? = nil, width: Int, height: Int,
                layout: Size? = nil, natural: Size? = nil) {
        self.name = name
        self.status = status
        self.error = error
        self.redrawn = redrawn
        self.width = width
        self.height = height
        self.layoutWidth = layout?.width
        self.layoutHeight = layout?.height
        self.naturalWidth = natural?.width
        self.naturalHeight = natural?.height
    }

    public static func encode(_ entries: [ManifestEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(entries)
    }
}
