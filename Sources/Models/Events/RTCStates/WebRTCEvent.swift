//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation

public enum WebRTCEvent: Sendable, Hashable, Codable, CustomStringConvertible {
    case iceConnectionState(ICEConnectionState)
    case iceGatheringState(ICEGatheringState)
    case signalingState(SignalingState)
    case peerConnectionState(PeerConnectionState)
}

public extension WebRTCEvent {
    var description: String {
        switch self {
        case let .iceConnectionState(event): return ".iceConnectionState(\(event))"
        case let .iceGatheringState(event): return ".iceGatheringState(\(event))"
        case let .signalingState(event): return ".signalingState(\(event))"
        case let .peerConnectionState(event): return ".peerConnectionState(\(event))"
        }
    }
}

public extension WebRTCEvent {
    var iceConnectionState: ICEConnectionState? {
        guard case .iceConnectionState(let iceConnectionState) = self else {
            return nil
        }
        return iceConnectionState
    }
}
