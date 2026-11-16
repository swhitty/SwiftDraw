import CryptoKit
public import Foundation

/// A folder of renders keyed by renderer and input, so stable renderers (WebKit, resvg, SwiftDraw at
/// a commit) only run for files they haven't seen. Each entry is `<renderer>/<key>.json` (the result)
/// plus `<renderer>/<key>.png` when it rendered.
public struct RenderCache: Sendable {
    /// nil disables caching.
    public var root: URL?

    public init(root: URL?) {
        self.root = root
    }

    public static var defaultRoot: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("swiftdraw-diff")
    }

    /// The cached result and PNG, if present. The PNG is nil for a cached failure.
    public func lookup<Meta: Decodable>(_ renderer: String, _ key: String, as: Meta.Type) -> (meta: Meta, png: URL?)? {
        guard let dir = root?.appendingPathComponent("renders/\(renderer)"),
              let data = try? Data(contentsOf: dir.appendingPathComponent("\(key).json")),
              let meta = try? JSONDecoder().decode(Meta.self, from: data) else { return nil }
        let png = dir.appendingPathComponent("\(key).png")
        return (meta, FileManager.default.fileExists(atPath: png.path) ? png : nil)
    }

    /// Stores a result and (optionally) its PNG. Failures to write are ignored: the cache is an optimisation.
    public func store<Meta: Encodable>(_ renderer: String, _ key: String, meta: Meta, png: URL?) {
        guard let dir = root?.appendingPathComponent("renders/\(renderer)") else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent("\(key).png")
        try? fm.removeItem(at: target)
        if let png { try? fm.copyItem(at: png, to: target) }
        // the result last, so a lookup never finds a result without its PNG
        try? JSONEncoder().encode(meta).write(to: dir.appendingPathComponent("\(key).json"), options: .atomic)
    }

    /// A cached swiftdrawcli binary for a SwiftDraw commit.
    public func swiftdrawBinary(sha: String) -> URL? {
        root?.appendingPathComponent("swiftdrawcli/\(sha)/swiftdrawcli")
    }

    public static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func hash(_ parts: String...) -> String {
        String(hash(Data(parts.joined(separator: "\u{1F}").utf8)).prefix(24))
    }
}
