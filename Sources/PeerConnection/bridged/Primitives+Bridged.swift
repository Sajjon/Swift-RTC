//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import WebRTC
import RTCModels

extension ICECandidate {
    func rtc() -> RTCIceCandidate {
        .init(
            sdp: sdp,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid
        )
    }
}

extension RTCIceCandidate {
    var ice: ICECandidate {
        .init(
            sdp: sdp,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid
        )
    }
}

extension Answer {
    func rtc() -> RTCSessionDescription {
        .init(type: .answer, sdp: sdp)
    }
}

extension Offer {
    func rtc() -> RTCSessionDescription {
        .init(type: .offer, sdp: sdp)
    }
}

extension RTCSessionDescription {
    
    func answer() throws -> Answer {
        guard type == .answer else {
            struct NoAnAnswer: Swift.Error {}
            throw NoAnAnswer()
        }
        return .init(sdp: sdp)
    }
    
    func offer() throws -> Offer {
        guard type == .offer else {
            struct NoAnOffer: Swift.Error {}
            throw NoAnOffer()
        }
        return .init(sdp: sdp)
    }
}


