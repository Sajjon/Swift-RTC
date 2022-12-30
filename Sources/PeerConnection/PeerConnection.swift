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
    
    typealias Channels = Disposables<Channel>
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
        let delegate = PeerConnectionDelegate(peerConnectionID: id, negotiationRole: negotiationRole)
        self.delegate = delegate
        var optionalConstraints: [String: String] = [:]
        if config.defineDtlsSrtpKeyAgreement {
            optionalConstraints[dtlsSRTPKeyAgreement] = kRTCMediaConstraintsValueTrue
        }
        
        guard
            let peerConnection = RTCPeerConnectionFactory().peerConnection(
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

public extension PeerConnection {
    static func == (lhs: PeerConnection, rhs: PeerConnection) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public extension PeerConnection {
    nonisolated var shouldNegotiateAsyncSequence: AsyncStream<NegotiationRole> {
        delegate.shouldNegotiateAsyncSequence
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
    ) async throws -> Channel {
        try await channels.assertUnique(id: id)
        
        // This will trigger `shouldNegotiate`
        guard let dataChannel = peerConnection.dataChannel(
            forLabel: id.label,
            configuration: config.rtc(dataChannelID: id)
        ) else {
            throw Error.failedToCreateDataChannel
        }

        //assert(dataChannel.channelId == id.id, "Expected channelId to be: \(id.id), but was: \(dataChannel.channelId)")
        dataChannel.delegate = delegate

        let channel = Channel(
            id: id,
            dataChannel: dataChannel
        )

        let task = Task { [unowned self] in
            
            await withThrowingTaskGroup(of: Void.self) { group in
                
                // Update connectionStatus
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    for await readyState in self.delegate.dataChannelUpdateOfReadyStateAsyncSequence
                        .filter({ $0.channelID == id })
                        .map({ $0.value })
                    {
                        guard !Task.isCancelled else { return }
                        await channel.updateReadyState(readyState)
                    }
                }
                
                // Receive data
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    for await data in self.delegate.dataChannelUpdateOfMessageReceivedAsyncSequence
                        .filter({ $0.channelID == id })
                        .map({ $0.value })
                    {
                        guard !Task.isCancelled else { return }
                        await channel.received(data: data)
                    }
                }
            }
            
      
        }
        try await channels.insert(.init(element: channel, task: task))
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
        do {
            try await self.peerConnection.add(ice.rtc())
        } catch {
            let nsError = error as NSError
            if nsError.domain == "org.webrtc.RTC_OBJC_TYPE(RTCPeerConnection)" && nsError.code == 6 && (nsError.userInfo[NSLocalizedDescriptionKey] as? NSString) == "The remote description was null" {
                print("\n\n⚠️⚠️⚠️ WARNING SUPRESSED ERROR ⚠️⚠️⚠️:\n `\(error.localizedDescription)`\n⚠️⚠️⚠️⚠️⚠️⚠️\n")
            } else {
                debugPrint("Failed to set ICE: \(String(describing: error))")
                throw error
            }
        }
    }
    
    @MainActor
    func removeICECandidates(_ ices: [ICECandidate]) {
        let iceCandidates = ices.map { $0.rtc() }
        peerConnection.remove(iceCandidates)
    }
}

