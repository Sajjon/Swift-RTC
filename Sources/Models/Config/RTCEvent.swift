//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation

public enum RTCEvent: Sendable, Hashable, Codable, CustomStringConvertible {
    case webRTC(WebRTCEvent)
    case sessionInitiationProtocolEvent(SessionInitiationProtocolEvent)
}

public extension RTCEvent {
    var description: String {
        switch self {
        case let .webRTC(event): return ".webRTC(\(event))"
        case let .sessionInitiationProtocolEvent(event): return ".sessionInitiationProtocolEvent(\(event))"
        }
    }
}

public extension RTCEvent {
    
    var webRTC: WebRTCEvent? {
        guard case .webRTC(let webRTCEvent) = self else {
            return nil
        }
        return webRTCEvent
    }
    
    var sessionInitiationProtocolEvent: SessionInitiationProtocolEvent? {
        guard case .sessionInitiationProtocolEvent(let sipEvent) = self else {
            return nil
        }
        return sipEvent
    }
}
