//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import WebRTC
import RTCModels

public actor PeerConnection: Disconnecting {
    nonisolated public let id: ID
    public let negotiationRole: NegotiationRole
    public let config: WebRTCConfig
    
    private let peerConnection: RTCPeerConnection
    
    typealias Channels = Disposables<Tunnel<DataChannelID, DataChannelState, Data, Data>>
    private let channels: Channels = .init()

    private let delegate: PeerConnectionDelegate

    public init(
        id: PeerConnectionID,
        config: WebRTCConfig,
        negotiationRole: NegotiationRole
    ) throws {
        self.id = id
        self.config = config
        self.negotiationRole = negotiationRole
       
        let delegate = PeerConnectionDelegate(
            peerConnectionID: id,
            negotiationRole: negotiationRole
        )
        
        self.delegate = delegate
        
        var optionalConstraints: [String: String] = [:]
        if config.defineDtlsSrtpKeyAgreement {
            optionalConstraints[dtlsSRTPKeyAgreement] = kRTCMediaConstraintsValueTrue
        }
        
        guard
            let peerConnection = Self.factory.peerConnection(
                with: config.rtc(),
                constraints: .init(
                    mandatoryConstraints: nil,
                    optionalConstraints: optionalConstraints
                ),
                delegate: nil
            )
        else {
            throw Error.failedToCreatePeerConnection
        }
        
        self.peerConnection = peerConnection
        self.peerConnection.delegate = delegate
    }
}

// NARK: Equatable
public extension PeerConnection {
    static func == (lhs: PeerConnection, rhs: PeerConnection) -> Bool {
        lhs.id == rhs.id
    }
}

// NARK: Hashable
public extension PeerConnection {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: Async Sequences
public extension PeerConnection {
    
    nonisolated var shouldNegotiateAsyncSequence: AsyncStream<NegotiationRole> {
        delegate.shouldNegotiateAsyncSequence
    }
    
    nonisolated var iceConnectionStateAsyncSequence: AsyncStream<ICEConnectionState> {
        delegate.iceConnectionStateAsyncSequence
    }
    
    nonisolated var signalingStateAsyncSequence: AsyncStream<SignalingState> {
        delegate.signalingStateAsyncSequence
    }
    
    nonisolated var generatedICECandidateAsyncSequence: AsyncStream<ICECandidate> {
        delegate.generatedICECandidateAsyncSequence
    }
    
    nonisolated var removeICECandidatesAsyncSequence: AsyncStream<[ICECandidate]> {
        delegate.removeICECandidatesAsyncSequence
    }
}

public extension PeerConnection {
    typealias ID = PeerConnectionID
    enum Error: String, LocalizedError, Sendable {
        case failedToCreatePeerConnection
        case failedToCreateDataChannel
    }
}
private let dtlsSRTPKeyAgreement = "DtlsSrtpKeyAgreement"
private extension PeerConnection {
    static var negotiationConstraints: RTCMediaConstraints {
        .init(mandatoryConstraints: [:], optionalConstraints: [:])
    }

}

// MARK: Channel
public extension PeerConnection {
    
    func newChannel(
        id: DataChannelID,
        config: DataChannelConfig
    ) async throws -> Tunnel<DataChannelID, DataChannelState, Data, Data> {
        
        try await channels.assertUnique(id: id)
        
        // This will trigger `shouldNegotiate`
        guard let dataChannel = peerConnection.dataChannel(
            forLabel: id.label,
            configuration: config.rtc(dataChannelID: id)
        ) else {
            throw Error.failedToCreateDataChannel
        }

        let dataChannelDelegate = DataChannelDelegate(
            peerConnectionID: self.id,
            dataChannelID: id
        )
        
        dataChannel.delegate = dataChannelDelegate
        
        let channel = Tunnel.multicast(
            dataChannel: dataChannel,
            dataChannelDelegate: dataChannelDelegate
        )

        try await channels.insert(
            .init(
                element: channel,
                referencingStrongly: dataChannelDelegate
            )
        )
        return channel
    }
}

// MARK: Disconnecting
public extension PeerConnection {
    func disconnect() async {
        await channels.cancelDisconnectAndRemoveAll()
        peerConnection.close()
        peerConnection.delegate = nil
    }
    
    func closeChannel(id channelID: DataChannelID) async {
        await channels.cancelDisconnectAndRemove(id: channelID)
    }
}


// MARK: Negotiation
public extension PeerConnection {
    
    @MainActor
    func offer() async throws -> Offer {
        let localSDP = try await peerConnection.offer(for: Self.negotiationConstraints)
        try await peerConnection.setLocalDescription(localSDP)
        return Offer(sdp: localSDP.sdp)
    }
    
    @MainActor
    func answer() async throws -> Answer {
        let localSDP = try await peerConnection.answer(for: Self.negotiationConstraints)
        try await peerConnection.setLocalDescription(localSDP)
        return Answer(sdp: localSDP.sdp)
    }
    
    @MainActor
    func setRemoteOffer(_ offer: Offer) async throws {
        let sdp = offer.rtc()
        try await peerConnection.setRemoteDescription(sdp)
    }
    
    @MainActor
    func setRemoteAnswer(_ answer: Answer) async throws {
        let sdp = answer.rtc()
        try await peerConnection.setRemoteDescription(sdp)
    }
    
    @MainActor
    func addRemoteICE(_ ice: ICECandidate) async throws {
        try await self.peerConnection.add(ice.rtc())
    }
    
    @MainActor
    func removeICECandidates(_ ices: [ICECandidate]) {
        let iceCandidates = ices.map { $0.rtc() }
        peerConnection.remove(iceCandidates)
    }
}

// MARK: Factory
extension PeerConnection {
    static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory
        )
    }()
    
}
