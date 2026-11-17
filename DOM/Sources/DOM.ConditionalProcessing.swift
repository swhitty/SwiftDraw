//
//  DOM.ConditionalProcessing.swift
//  SwiftDraw
//
//  Copyright 2026 Simon Whitty
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

import Foundation

package extension DOM.GraphicsElement {

    /// SVG 2 §5.8.4: whether the conditional processing attributes evaluate to true for a user
    /// whose preferred languages are `languages` (BCP 47 tags, most preferred first).
    /// An element that fails is not rendered, and is passed over by a `<switch>`.
    func passesConditions(languages: [String]) -> Bool {
        // no extensions are supported: any requiredExtensions, even empty, is false (SVG 2, resvg)
        guard requiredExtensions == nil else { return false }
        guard let systemLanguage else { return true }
        return DOM.matchesSystemLanguage(systemLanguage, languages: languages)
    }
}

package extension DOM {

    /// `systemLanguage` is a comma-separated list of BCP 47 tags, true when any tag shares its primary
    /// language subtag with one of `languages`, ignoring case. As in browsers and resvg, `en-GB` matches a
    /// user preferring `en-US`, rather than SVG 2's stricter prefix match. An empty list is false.
    static func matchesSystemLanguage(_ value: String, languages: [String]) -> Bool {
        let preferred = Set(languages.compactMap(primaryLanguageSubtag))
        return
            value
            .split(separator: ",")
            .compactMap { primaryLanguageSubtag(String($0)) }
            .contains { preferred.contains($0) }
    }

    /// The lowercased primary language subtag of a BCP 47 tag (`en` of `en-US`), accepting `_` as
    /// used by POSIX locales; nil when empty.
    static func primaryLanguageSubtag(_ tag: String) -> String? {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let primary = trimmed.split(whereSeparator: { $0 == "-" || $0 == "_" }).first,
            !primary.isEmpty
        else { return nil }
        return primary.lowercased()
    }
}
