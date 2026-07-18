//
//  View+Task.swift
//  SwiftDraw
//
//  Created by Simon Whitty on 19/7/26.
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

#if canImport(SwiftUI)
import Combine
import SwiftUI

extension View {

    @ViewBuilder
    func compatibilityTask<ID: Equatable>(
        id: ID,
        priority: TaskPriority = .userInitiated,
        @_inheritActorContext _ action: @escaping @Sendable () async -> Void
    ) -> some View {
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            task(id: id, priority: priority, action)
        } else {
            modifier(CompatibilityTaskModifier(
                id: id,
                priority: priority,
                action: action
            ))
        }
    }
}

private struct CompatibilityTaskModifier<ID: Equatable>: ViewModifier {

    let id: ID
    let priority: TaskPriority
    let action: @Sendable () async -> Void

    @State private var currentID: ID?
    @State private var isVisible = false
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                startTaskIfNeeded(id: id)
            }
            .onReceive(Just(id)) { id in
                guard isVisible else { return }
                startTaskIfNeeded(id: id)
            }
            .onDisappear {
                isVisible = false
                currentID = nil
                task?.cancel()
                task = nil
            }
    }

    private func startTaskIfNeeded(id: ID) {
        guard currentID != id else { return }
        currentID = id
        task?.cancel()
        task = Task(priority: priority) {
            await action()
        }
    }
}

#endif
