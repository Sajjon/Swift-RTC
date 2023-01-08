//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import WebRTC
import P2PModels

extension RTCSignalingState {
    func swiftify() -> SignalingState {
        switch self {
        case .closed:
            return .closed
        case .stable:
            return .stable
        case .haveLocalOffer:
            return .haveLocalOffer
        case .haveLocalPrAnswer:
            return .haveLocalPrAnswer
        case .haveRemoteOffer:
            return .haveRemoteOffer
        case .haveRemotePrAnswer:
            return .haveRemotePrAnswer
        @unknown default:
            fatalError("Unknown signalingState: \(self)")
        }
    }
}
extension RTCIceConnectionState {
    func swiftify() -> ICEConnectionState {
        switch self {
        case .new: return .new
        case .checking: return .checking
        case .connected: return .connected
        case .completed: return .completed
        case .failed: return .failed
        case .disconnected: return .disconnected
        case .closed: return .closed
        case .count:
            fatalError()
        @unknown default:
            fatalError()
        }
    }
}

extension RTCPeerConnectionState {
    func swiftify() -> PeerConnectionState {
        switch self {
        case .closed: return .closed
        case .new: return .new
        case .connecting: return .connecting
        case .connected: return .connected
        case .disconnected: return .disconnected
        case .failed: return .failed
        @unknown default:
            fatalError()
        }
    }
}

extension RTCIceGatheringState {
    func swiftify() -> ICEGatheringState {
        switch self {
        case .gathering:
            return .gathering
        case .new:
            return .new
        case .complete:
            return .complete
        @unknown default:
            fatalError()
        }
    }
}


extension RTCDataChannelState {
    func swiftify() -> DataChannelState {
        switch self {
        case .open: return .open
        case .connecting: return .connecting
        case .closed: return .closed
        case .closing: return .closing
        @unknown default:
            fatalError()
        }
    }
}
