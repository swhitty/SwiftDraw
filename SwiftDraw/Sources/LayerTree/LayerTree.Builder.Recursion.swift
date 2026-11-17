//
//  LayerTree.Builder.Recursion.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 17/11/26.
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

import SwiftDrawDOM
import Foundation

// Recursive references between patterns, masks and markers, and recursive <use>.
//
// A reference that leads back to the pattern, mask or marker containing it is invalid, and is
// dropped from the document before anything is built, as in Chrome and resvg: a fill or stroke
// becomes `none`, a mask or marker is ignored. The containers are checked in document order,
// and only the reference that closes a cycle is dropped, so in `A → B → A` checked from A, B
// keeps drawing A's contents without B. Like resvg, each copy of an element a `<use>` draws is
// checked on its own: a reference is identified by the element and the `<use>` elements expanded
// to reach it since the enclosing pattern, mask or marker. The `building(_:cycle:)` guard still
// bounds anything this pass does not reach.

extension LayerTree.Builder {

    /// A property of an element that references a pattern, mask or marker.
    struct Reference: Hashable {
        enum Property: Hashable {
            case fill
            case stroke
            case mask
            case markerStart
            case markerMid
            case markerEnd
        }

        var element: ObjectIdentifier
        var property: Property
        /// The `<use>` elements expanded to reach the element, since the enclosing pattern, mask or marker.
        var instance: [ObjectIdentifier]

        init(_ element: DOM.GraphicsElement, _ property: Property, instance: [ObjectIdentifier]) {
            self.element = ObjectIdentifier(element)
            self.property = property
            self.instance = instance
        }
    }

    /// A pattern, mask or marker, by id: only the first with an id is ever referenced.
    enum ReferencedContainer: Hashable {
        case mask(String)
        case pattern(String)
        case marker(String)
    }

    /// The references dropped because they lead back to the container they are in, and the
    /// `<use>` elements that draw themselves; found once per document.
    final class Recursion {
        var invalidReferences: Set<Reference>?
        /// The `<use>` elements being expanded since the pattern, mask or marker being built.
        var instance = [ObjectIdentifier]()
        var recursiveUses = [ObjectIdentifier: Bool]()
        /// Elements visited checking `<use>` for recursion, document-wide.
        var useSteps = 0
        /// The ancestors of the elements `<feImage>` references, found once each.
        var ancestors = [ObjectIdentifier: [DOM.GraphicsElement]]()
    }

    /// Edges followed finding recursive references, document-wide. Past it the remaining
    /// references are kept, and only the `building(_:cycle:)` guard bounds them.
    static let maxRecursionSteps = 200_000
    /// Elements visited checking every `<use>` for recursion, document-wide.
    static let maxUseRecursionSteps = 200_000

    func isInvalid(_ element: DOM.GraphicsElement, _ property: Reference.Property) -> Bool {
        let invalid = invalidReferences
        return !invalid.isEmpty && invalid.contains(Reference(element, property, instance: recursion.instance))
    }

    /// Builds the contents of a pattern, mask or marker, whose references are identified from there.
    func buildingContents<R>(_ build: () throws -> R) rethrows -> R {
        let instance = recursion.instance
        recursion.instance = []
        defer { recursion.instance = instance }
        return try build()
    }

    /// Builds what `use` draws, whose references are identified through it.
    func expanding<R>(_ use: DOM.Use, _ build: () throws -> R) rethrows -> R {
        recursion.instance.append(ObjectIdentifier(use))
        defer { recursion.instance.removeLast() }
        return try build()
    }

    var invalidReferences: Set<Reference> {
        if let invalid = recursion.invalidReferences { return invalid }
        let invalid = makeInvalidReferences()
        recursion.invalidReferences = invalid
        return invalid
    }

    /// The state the contents of a pattern, mask or marker inherit: from the container's ancestors,
    /// not from the element referencing it. `display` does not inherit.
    func makeInheritedState(from ancestors: [DOM.GraphicsElement]) -> State {
        var state = State()
        for ancestor in ancestors {
            state = createReferencedState(for: ancestor, inheriting: state)
        }
        state.display = .inline
        return state
    }

    /// The state of an element before invalid references are dropped.
    func createReferencedState(for element: DOM.GraphicsElement, inheriting existing: State) -> State {
        let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
        var state = Self.createState(for: attributes, inheriting: existing, viewportDiagonal: viewportDiagonal)
        // `baseline-shift` applies to the text content elements within <text> (as resvg, not to the
        // <text> itself), and those nested add up
        if element is DOM.TextSpan || element is DOM.TextPath,
            let shift = state.baselineShift
        {
            state.baselineShifts.append(BaselineShiftEntry(shift: shift, fontSize: state.fontSize))
        }
        return state
    }

    func makeInvalidReferences() -> Set<Reference> {
        var containers = [(order: Int, container: ReferencedContainer)]()
        var seen = Set<ReferencedContainer>()
        func append(_ container: ReferencedContainer, id: String) {
            guard seen.insert(container).inserted else { return }
            containers.append((svg.defs.documentOrder[id] ?? Int.max, container))
        }
        for id in svg.defs.masks.compactMap(\.id) { append(.mask(id), id: id) }
        for id in svg.defs.patterns.map(\.id) { append(.pattern(id), id: id) }
        for id in svg.defs.markers.compactMap(\.id) { append(.marker(id), id: id) }
        guard !containers.isEmpty else { return [] }
        let ordered = containers.enumerated()
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
            .map(\.element.container)

        // the first of each id is the one referenced
        let lookup = ContainerLookup(
            masks: Dictionary(svg.defs.masks.compactMap { m in m.id.map { ($0, m) } }, uniquingKeysWith: { a, _ in a }),
            patterns: Dictionary(svg.defs.patterns.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }),
            markers: Dictionary(
                svg.defs.markers.compactMap { m in m.id.map { ($0, m) } },
                uniquingKeysWith: { a, _ in a }
            )
        )
        var edges = [ReferencedContainer: [(Reference, ReferencedContainer)]]()
        func edgesOf(_ container: ReferencedContainer) -> [(Reference, ReferencedContainer)] {
            if let cached = edges[container] { return cached }
            let found = makeReferences(in: container, lookup: lookup)
            edges[container] = found
            return found
        }

        var invalid = Set<Reference>()
        var steps = 0
        for start in ordered {
            var visited: Set<ReferencedContainer> = [start]
            var stack = [start]
            while let container = stack.popLast() {
                for (reference, target) in edgesOf(container) where !invalid.contains(reference) {
                    steps += 1
                    guard steps <= Self.maxRecursionSteps else { return invalid }
                    if target == start {
                        invalid.insert(reference)
                    } else if visited.insert(target).inserted {
                        stack.append(target)
                    }
                }
            }
        }
        return invalid
    }

    /// The masks, patterns and markers by id.
    struct ContainerLookup {
        var masks: [String: DOM.Mask]
        var patterns: [String: DOM.Pattern]
        var markers: [String: DOM.Marker]
    }

    /// The references to patterns, masks and markers made by the contents of `container`,
    /// including what the `<use>` elements there draw.
    func makeReferences(
        in container: ReferencedContainer,
        lookup: ContainerLookup
    ) -> [(Reference, ReferencedContainer)] {
        let children: [DOM.GraphicsElement]
        let state: State
        switch container {
        case .mask(let id):
            guard let mask = lookup.masks[id] else { return [] }
            children = mask.childElements
            state = createReferencedState(for: mask, inheriting: makeInheritedState(from: mask.ancestors))
        case .pattern(let id):
            guard let pattern = lookup.patterns[id] else { return [] }
            let template = makePatternChain(for: pattern).first { !$0.childElements.isEmpty }
            children = template?.childElements ?? []
            state = makeInheritedState(from: template?.ancestors ?? [])
        case .marker(let id):
            guard let marker = lookup.markers[id] else { return [] }
            children = marker.childElements
            state = createReferencedState(for: marker, inheriting: makeInheritedState(from: marker.ancestors))
        }

        struct Item {
            var element: DOM.GraphicsElement
            var state: State
            var instance: [ObjectIdentifier]
            /// The element a `<use>` draws, which may be a `<symbol>`
            var isUseTarget = false
        }
        var references = [(Reference, ReferencedContainer)]()
        var stack = children.reversed().map { Item(element: $0, state: state, instance: []) }
        var steps = 0
        while let item = stack.popLast() {
            // an element drawn by uses fanning out at every level is visited once per copy
            steps += 1
            guard steps <= Self.maxRecursionSteps else { break }
            let element = item.element
            let instance = item.instance
            let state = createReferencedState(for: element, inheriting: item.state)
            guard state.display != .none else { continue }

            let attributes = DOM.presentationAttributes(for: element, styles: svg.styles)
            if let id = attributes.mask?.fragmentID, lookup.masks[id] != nil {
                references.append((Reference(element, .mask, instance: instance), .mask(id)))
            }

            let isShape = Self.makeShape(from: element) != nil
            if isShape || element is DOM.Text {
                if case .url(let url) = state.fill, let id = url.fragmentID, lookup.patterns[id] != nil {
                    references.append((Reference(element, .fill, instance: instance), .pattern(id)))
                }
                if case .url(let url) = state.stroke, let id = url.fragmentID, lookup.patterns[id] != nil {
                    references.append((Reference(element, .stroke, instance: instance), .pattern(id)))
                }
            }
            if isShape {
                let markers: [(DOM.URL?, Reference.Property)] = [
                    (state.markerStart, .markerStart), (state.markerMid, .markerMid), (state.markerEnd, .markerEnd),
                ]
                for (url, property) in markers {
                    if let id = url?.fragmentID, lookup.markers[id] != nil {
                        references.append((Reference(element, property, instance: instance), .marker(id)))
                    }
                }
            }

            if let use = element as? DOM.Use {
                // a recursive use draws nothing, and the building guard limits the depth
                let key = ObjectIdentifier(use)
                guard !instance.contains(key), instance.count < Self.maxReferenceDepth, !isRecursive(use),
                    let target = use.href.fragmentID.flatMap(svg.firstGraphicsElement)
                else { continue }
                stack.append(Item(element: target, state: state, instance: instance + [key], isUseTarget: true))
            } else if !(element is DOM.Symbol) || item.isUseTarget,
                let container = element as? any ContainerElement
            {
                stack.append(
                    contentsOf: container.childElements.reversed().map {
                        Item(element: $0, state: state, instance: instance)
                    }
                )
            }
        }
        return references
    }

    /// Whether drawing `use` draws `use` again, directly or through other `<use>` elements, such as a
    /// `<use>` of its own ancestor. Chrome and resvg draw nothing for such a `<use>`.
    func isRecursive(_ use: DOM.Use) -> Bool {
        let key = ObjectIdentifier(use)
        if let cached = recursion.recursiveUses[key] { return cached }

        var result = false
        var visited: Set<ObjectIdentifier> = [key]
        var stack = [DOM.GraphicsElement]()
        if let target = use.href.fragmentID.flatMap(svg.firstGraphicsElement) {
            stack.append(target)
        }
        search: while let element = stack.popLast() {
            recursion.useSteps += 1
            guard recursion.useSteps <= Self.maxUseRecursionSteps else { break }
            if let inner = element as? DOM.Use {
                if inner === use {
                    result = true
                    break search
                }
                if visited.insert(ObjectIdentifier(inner)).inserted,
                    let target = inner.href.fragmentID.flatMap(svg.firstGraphicsElement)
                {
                    stack.append(target)
                }
            } else if let container = element as? any ContainerElement {
                stack.append(contentsOf: container.childElements)
            }
        }
        recursion.recursiveUses[key] = result
        return result
    }
}
