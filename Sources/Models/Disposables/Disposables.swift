//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import Foundation

/// A Key-Value store of `Element`s wrapped in `Disposable`, which holds a reference to a cancellable
/// task.
public actor Disposables<Element: Disconnecting>: Sendable {
    private var disposables: [ID: Disposable<Element>] = [:]
    public init() {}
}

// MARK: Public
public extension Disposables {
    typealias ID = Element.ID
   
    func containsID(_ id: ID) -> Bool {
        disposables.keys.contains(id)
    }
   
    func assertUnique(id: ID) throws {
        guard !containsID(id) else {
            throw Error.elementAlreadyExists
        }
    }
   
    func insert(_ disposable: Disposable<Element>) async throws {
        let id = disposable.id
        try assertUnique(id: id)
        disposables[id] = disposable
    }
    
    func get(id: ID) async throws -> Element {
        guard let disposable = disposables[id] else {
            throw Error.elementNotFound
        }
        return disposable.element
    }
    
    func cancelDisconnectAndRemove(id: ID) async {
        guard let disposable = disposables[id] else { return }
        await disposable.disconnectAndCancel()
    }
    
    func cancelDisconnectAndRemoveAll() async {
        for id in disposables.keys {
            await cancelDisconnectAndRemove(id: id)
        }
        disposables.removeAll()
    }
}

// MARK: Error
public extension Disposables {
    enum Error: String, LocalizedError, Hashable {
        case elementAlreadyExists
        case elementNotFound
    }
}
