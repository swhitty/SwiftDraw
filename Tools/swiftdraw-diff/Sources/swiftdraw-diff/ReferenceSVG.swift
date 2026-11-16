import Foundation

/// The SVG that WebKit renders as the reference. A copy of `Tools/webkit-render`'s ReferenceSVG, kept
/// until swiftdraw-diff runs webkit-render instead of scoring in its own page.
///
///
/// WebKit draws text through macOS font smoothing, which makes glyphs heavier than their outlines.
/// SwiftDraw fills the glyph outlines, so by default the reference turns smoothing off
/// (`-webkit-font-smoothing: antialiased`) and text differences reflect real rendering bugs rather than
/// rasterization. `--font-smoothing` keeps WebKit's default, which is what browsers show.
///
/// The SVG is shown through an `<img>`, so a stylesheet on the host page cannot reach it: the rule is
/// inserted as a `<style>` element right after the root `<svg …>` tag.
enum ReferenceSVG {

    static let disableFontSmoothing = "<style>svg{-webkit-font-smoothing:antialiased}</style>"

    static func prepare(_ data: Data, fontSmoothing: Bool) -> Data {
        guard !fontSmoothing,
              let text = String(data: data, encoding: .utf8),
              let end = rootTagEnd(in: text) else {
            return data
        }
        var prepared = text
        prepared.insert(contentsOf: disableFontSmoothing, at: end)
        return Data(prepared.utf8)
    }

    /// The index just after the `>` of the root `<svg …>` start tag, skipping the XML declaration,
    /// comments and DOCTYPE. nil when there is none, or when the root is self-closing.
    static func rootTagEnd(in text: String) -> String.Index? {
        var index = text.startIndex
        while let open = text[index...].firstIndex(of: "<") {
            let rest = text[open...]
            if rest.hasPrefix("<?") || rest.hasPrefix("<!") {
                // declaration, comment or DOCTYPE: skip past its end
                let terminator = rest.hasPrefix("<!--") ? "-->" : ">"
                guard let close = rest.range(of: terminator) else { return nil }
                index = close.upperBound
                continue
            }
            guard rest.hasPrefix("<svg") || rest.range(of: #"^<[A-Za-z_][\w.-]*:svg"#, options: .regularExpression) != nil else {
                return nil
            }
            // the end of the start tag: the first `>` outside quoted attribute values
            var quote: Character?
            var i = open
            while i < text.endIndex {
                let c = text[i]
                if let q = quote {
                    if c == q { quote = nil }
                } else if c == "\"" || c == "'" {
                    quote = c
                } else if c == ">" {
                    return text[text.index(before: i)] == "/" ? nil : text.index(after: i)
                }
                i = text.index(after: i)
            }
            return nil
        }
        return nil
    }
}
