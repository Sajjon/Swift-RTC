//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import Foundation

public actor Disposable<Element>: Sendable, Hashable, Identifiable where Element: Disconnecting {
    
    public let element: Element
    
    private var task: Task<Void, Never>?
    
    public init(
        element: Element,
        task: Task<Void, Never>
    ) {
        self.element = element
        self.task = task
    }
}

// MARK: Public
public extension Disposable {
    func disconnectAndCancel() async {
        await element.disconnect()
        task?.cancel()
        task = nil
    }
}

// MARK: Identifiable
public extension Disposable {
    typealias ID = Element.ID
    nonisolated var id: ID {
        element.id
    }
}

// MARK: Equatable
public extension Disposable {
    static func == (lhs: Disposable<Element>, rhs: Disposable<Element>) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: Hashable
public extension Disposable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
