//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-17.
//

import Foundation

public enum RadixSignalMsg: Sendable, Hashable {
    case incoming(Incoming)
    case outgoing(Outgoing)
}

public extension RadixSignalMsg {
    
    var incoming: Incoming? {
        switch self {
        case let .incoming(value): return value
        case .outgoing: return nil
        }
    }
    
    var outgoing: Outgoing? {
        switch self {
        case let .outgoing(value): return value
        case .incoming: return nil
        }
    }
    
}
