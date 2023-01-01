//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-30.
//

import Foundation
import WebRTC
import RTCModels

internal final class PeerConnectionDelegate:
    NSObject,
    Sendable,
    RTCPeerConnectionDelegate
{
    internal let shouldNegotiateAsyncSequence: AsyncStream<NegotiationRole>
    private let shouldNegotiateAsyncContinuation: AsyncStream<NegotiationRole>.Continuation
    
    internal let signalingStateAsyncSequence: AsyncStream<SignalingState>
    private let signalingStateAsyncContinuation: AsyncStream<SignalingState>.Continuation
    
    internal let generatedICECandidateAsyncSequence: AsyncStream<ICECandidate>
    private let generatedICECandidateAsyncContinutation: AsyncStream<ICECandidate>.Continuation
    
    internal let removeICECandidatesAsyncSequence: AsyncStream<[ICECandidate]>
    private let removeICECandidatesAsyncContinutation: AsyncStream<[ICECandidate]>.Continuation
    

    private let negotiationRole: NegotiationRole
    private let id: PeerConnectionID
    
    internal init(peerConnectionID: PeerConnectionID, negotiationRole: NegotiationRole) {
        self.id = peerConnectionID
        self.negotiationRole = negotiationRole
        
        (shouldNegotiateAsyncSequence, shouldNegotiateAsyncContinuation) = AsyncStream.streamWithContinuation(NegotiationRole.self)
        (signalingStateAsyncSequence, signalingStateAsyncContinuation) = AsyncStream.streamWithContinuation(SignalingState.self)
        
        (generatedICECandidateAsyncSequence, generatedICECandidateAsyncContinutation) = AsyncStream.streamWithContinuation(ICECandidate.self)
        
        (removeICECandidatesAsyncSequence, removeICECandidatesAsyncContinutation) = AsyncStream.streamWithContinuation([ICECandidate].self)

        
        super.init()
    }
}


// MARK: RTCPeerConnectionDelegate
internal extension PeerConnectionDelegate {

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didOpen dataChannel:\(dataChannel.channelId)")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), should Negotiate")
        shouldNegotiateAsyncContinuation.yield(negotiationRole)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        let state = stateChanged.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didChange SignalingState to: \(state)")
        signalingStateAsyncContinuation.yield(state)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let state = newState.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didChange IceConnectionState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didRemove stream: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didAdd stream: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        let state = newState.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didChange IceGatheringState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let iceCandidate = candidate.swiftify()
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didGenerate ICE")
        generatedICECandidateAsyncContinutation.yield(iceCandidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("\(peerConnection.hashValue % 100) peerConnection id: \(id), didRemove #\(candidates.count) ICE candidates")
        let iceCandidate = candidates.map { $0.swiftify() }
        removeICECandidatesAsyncContinutation.yield(iceCandidate)
    }
    
}
