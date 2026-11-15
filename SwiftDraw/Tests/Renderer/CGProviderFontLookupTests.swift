//
//  CGProviderFontLookupTests.swift
//  SwiftDraw
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/swhitty/SwiftDraw
//

#if canImport(CoreGraphics)
import CoreText
import Foundation
import Testing
@testable import SwiftDraw

struct CGProviderFontLookupTests {

    // macOS deadlocks when every thread of Swift's cooperative pool is in a CoreText font lookup at once,
    // so lookups are serialized: more tasks than threads must all complete. A regression hangs rather than
    // fails (a time limit can't free threads blocked in CoreText), which CI's step timeouts catch.
    @Test
    func concurrentLookupsFromEveryPoolThreadComplete() async {
        let families = ["Chalkduster", "Impact", "Helvetica", "Helvetica-Bold", "Times", "No Such Font"]
        let tasks = ProcessInfo.processInfo.activeProcessorCount * 4

        let created = await withTaskGroup(of: Int.self) { group in
            for index in 0..<tasks {
                group.addTask {
                    let family = families[index % families.count]
                    var count = 0
                    for weight in [300, 400, 700, 900] {
                        let font = CGProvider.createFont(for: [.name(family)], size: 12, weight: weight, isItalic: index.isMultiple(of: 2))
                        count += CTFontGetSize(font.font) == 12 ? 1 : 0
                    }
                    _ = CGProvider.installedFontPostScriptName(family)
                    return count
                }
            }
            return await group.reduce(0, +)
        }

        #expect(created == tasks * 4)
    }
}
#endif
