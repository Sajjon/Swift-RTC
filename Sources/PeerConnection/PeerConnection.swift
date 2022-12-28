//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import WebRTC
import RTCModels

private extension PeerConnection {
    actor Channels {
        
        private var channels: [DataChannelID: RTCDataChannel] = [:]
        
        init() {
            
        }
        
        enum Error: String, LocalizedError, Hashable {
            case channelAlreadyExists
        }
        func containsID(_ id: DataChannelID) -> Bool {
            channels.keys.contains(id)
        }
        func assertUnique(id: DataChannelID) throws {
            guard !containsID(id) else {
                throw Error.channelAlreadyExists
            }
        }
        func insert(channel: RTCDataChannel, id: DataChannelID) async throws {
            try assertUnique(id: id)
            channels[id] = channel
        }
    }
}

public final class PeerConnection:
    NSObject,
    RTCPeerConnectionDelegate,
    RTCDataChannelDelegate,
    Identifiable
{
   
    public let id: ID
    public let config: WebRTCConfig

    private let peerConnection: RTCPeerConnection
    private let channels: Channels = .init()
    
    public let shouldNegotiateAsyncSequence: AsyncStream<Void>
    private let shouldNegotiateAsyncContinuation: AsyncStream<Void>.Continuation
    
    public init(
        id: PeerConnectionID,
        config: WebRTCConfig
    ) throws {
        self.id = id
        self.config = config
        
        guard
            let peerConnection = RTCPeerConnectionFactory().peerConnection(
                with: config.rtc(),
                constraints: .init(
                    mandatoryConstraints: nil,
                    optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
                ),
                delegate: nil
            )
        else {
            throw Error.failedToCreatePeerConnection
        }
        
        self.peerConnection = peerConnection
        
        var shouldNegotiateAsyncContinuation: AsyncStream<Void>.Continuation!
        let shouldNegotiateAsyncSequence: AsyncStream<Void> = .init { continuation in
            shouldNegotiateAsyncContinuation = continuation
        }
        self.shouldNegotiateAsyncSequence = shouldNegotiateAsyncSequence
        self.shouldNegotiateAsyncContinuation = shouldNegotiateAsyncContinuation
        
        super.init()
        
        self.peerConnection.delegate = self
    }
}

public extension PeerConnection {
    typealias ID = PeerConnectionID
    enum Error: String, LocalizedError, Sendable {
        case failedToCreatePeerConnection
        case failedToCreateDataChannel
    }
}

private extension PeerConnection {
    static var negotiationConstraints: RTCMediaConstraints {
        .init(mandatoryConstraints: [:], optionalConstraints: [:])
    }
}

// MARK: Channel
public extension PeerConnection {
    func newChannel(id: DataChannelID, config: DataChannelConfig) async throws {
        try await channels.assertUnique(id: id)
        
        // This will trigger `shouldNegotiate`
        guard let channel = peerConnection.dataChannel(
            forLabel: "Data", // move into config or param?
            configuration: config.rtc()
        ) else {
            throw Error.failedToCreateDataChannel
        }
        channel.delegate = self
        try await channels.insert(channel: channel, id: id)
    }
}

// MARK: Negotiation
public extension PeerConnection {
    
    func offer() async throws -> Offer {
        let localSDP = try await peerConnection.offer(for: Self.negotiationConstraints)
        try await peerConnection.setLocalDescription(localSDP)
        return Offer(sdp: localSDP.sdp)
    }
    
    func answer() async throws -> Answer {
        let localSDP = try await peerConnection.answer(for: Self.negotiationConstraints)
        try await peerConnection.setLocalDescription(localSDP)
        return Answer(sdp: localSDP.sdp)
    }

    func setRemoteOffer(_ offer: Offer) async throws {
        let sdp = offer.rtc()
        try await peerConnection.setRemoteDescription(sdp)
    }
    
    func setRemoteAnswer(_ answer: Answer) async throws {
        let sdp = answer.rtc()
        try await peerConnection.setRemoteDescription(sdp)
    }
}

// MARK: RTCPeerConnectionDelegate
public extension PeerConnection {
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("peerConnection id: \(id), didOpen dataChannel:\(dataChannel.channelId)")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("peerConnection id: \(id), should Negotiate")
        shouldNegotiateAsyncContinuation.yield()
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        let state = stateChanged.swiftify()
        debugPrint("peerConnection id: \(id), didChange SignalingState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let state = newState.swiftify()
        debugPrint("peerConnection id: \(id), didChange IceConnectionState to: \(state)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("peerConnection id: \(id), didRemove stream: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("peerConnection id: \(id), didAdd stream: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        let state = newState.swiftify()
        debugPrint("peerConnection id: \(id), didChange IceGatheringState to: \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        debugPrint("peerConnection id: \(id), didGenerate ICE")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("peerConnection id: \(id), didRemove #\(candidates.count) ICE candidates")
    }
    
}

// MARK: RTCDataChannelDelegate
public extension PeerConnection {
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        debugPrint("peerConnection id: \(id), dataChannel=\(dataChannel.channelId) didReceiveMessageWith #\(buffer.data.count) bytes")
    }
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let readyState = dataChannel.readyState.swiftify()
        debugPrint("peerConnection id: \(id), dataChannel=\(dataChannel.channelId) dataChannelDidChangeState to: \(readyState)")
    }
}
