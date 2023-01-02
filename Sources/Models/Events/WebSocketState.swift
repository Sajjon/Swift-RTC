//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-02.
//

import Foundation

// MARK: WebSocketState
public enum WebSocketState: Sendable, Hashable, Codable, CustomStringConvertible {
    case closed(WebSocketCloseCode)
    case closing
    case connected
    case connecting
}

public extension WebSocketState {
    var description: String {
        switch self {
        case let .closed(closed): return ".webRTC(\(closed))"
        case .closing: return ".closing"
        case .connected: return ".connected"
        case .connecting: return ".connecting"
        }
    }
}
