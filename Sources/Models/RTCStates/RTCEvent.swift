//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation

public enum RTCEvent: Sendable, Hashable, CustomStringConvertible {
    case iceConnectionState(ICEConnectionState)
    case iceGatheringState(ICEGatheringState)
    case signalingState(SignalingState)
    case peerConnectionState(PeerConnectionState)
}

public extension RTCEvent {
    var description: String {
        switch self {
        case let .iceConnectionState(event): return ".iceConnectionState(\(event))"
        case let .iceGatheringState(event): return ".iceGatheringState(\(event))"
        case let .signalingState(event): return ".signalingState(\(event))"
        case let .peerConnectionState(event): return ".peerConnectionState(\(event))"
        }
    }
}
