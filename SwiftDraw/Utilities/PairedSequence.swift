//
//  PairedSequence.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 6/8/22.
//  Copyright 2022 Simon Whitty
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

extension Sequence {

    // Iterate a sequence by including the next element each time.
    // A---B---C---D
    //
    // nextSkippingLast: (A,B)--(B,C)--(C,D)
    // nextWrappingToFirst: (A,B)--(B,C)--(C,D)--(D,A)
    func paired(with options: PairedSequence<Self>.Options = .nextWrappingToFirst) -> PairedSequence<Self> {
        PairedSequence(self, options: options)
    }
}

struct PairedSequence<S: Sequence>: Sequence {
    typealias Element = (S.Element, next: S.Element)

    enum Options {
        case nextSkippingLast
        case nextWrappingToFirst
    }

    init(_ inner: S, options: Options) {
        self.inner = inner
        self.options = options
    }

    private let inner: S
    private let options: Options

    func makeIterator() -> Iterator {
        return Iterator(inner.makeIterator(), options: options)
    }

    struct Iterator: IteratorProtocol {
        private var inner: S.Iterator
        private let options: Options

        init(_ inner: S.Iterator, options: Options) {
            self.inner = inner
            self.options = options
        }

        mutating func next() -> (S.Element, next: S.Element)? {
            guard !isComplete else { return  nil }

            guard let element = inner.next() else {
                isComplete = true
                return makeWrappedIfRequired()
            }

            if let previous = previous {
                self.previous = element
                return (previous, element)
            } else {
                first = element
                if let another = inner.next() {
                    self.previous = another
                    return (element, another)
                } else {
                    isComplete = true
                    return nil
                }
            }
        }

        private mutating func makeWrappedIfRequired() -> (S.Element, next: S.Element)? {
            guard options == .nextWrappingToFirst,
               let first = first,
               let previous = previous else {
                return nil
            }
            self.first = nil
            self.previous = nil
            return (previous, first)
        }

        private var isComplete: Bool = false
        private var first: S.Element?
        private var previous: S.Element?
    }
}
