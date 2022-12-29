//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import RTCPeerConnection
import RTCSignaling

public actor RTCClient {
  
    typealias Connections = Disposables<PeerConnection>
    private let signaling: SignalingClient
    private let connections: Connections = .init()
    
    public init(
        signaling: SignalingClient
    ) {
        self.signaling = signaling
    }
}

public extension RTCClient {
    
    func newChannel(
        peerConnectionID: PeerConnectionID,
        channelID: DataChannelID,
        config: DataChannelConfig
    ) async throws -> Channel {
        let peerConnection = try await connections.get(id: peerConnectionID)
        return try await peerConnection.newChannel(id: channelID, config: config)
    }
    
    func newConnection(
        id: PeerConnectionID,
        config: WebRTCConfig,
        negotiationRole: NegotiationRole
    ) async throws {
        
        try await connections.assertUnique(id: id)
        let peerConnection = try PeerConnection(
            id: id,
            config: config,
            negotiationRole: negotiationRole
        )
       
        let connectTask = Task {
            await withThrowingTaskGroup(of: Void.self) { group in
                // NEGOTIATION
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    for await negotiationRole in peerConnection.shouldNegotiateAsyncSequence {
                        guard !Task.isCancelled else { return }
                        try await self.negotiate(role: negotiationRole, peerConnection: peerConnection)
                    }
                }
                
                // ICE Exchange
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    for await ice in peerConnection.generatedICECandidateAsyncSequence {
                        guard !Task.isCancelled else { return }
                        try await self.signaling.sendToRemote(.addICE(ice))
                    }
                }
                
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    for await ices in peerConnection.removeICECandidatesAsyncSequence {
                        guard !Task.isCancelled else { return }
                        try await self.signaling.sendToRemote(.removeICEs(ices))
                    }
                }
            }
        }
  
        try await connections.insert(
            .init(
                element: peerConnection,
                task: connectTask
            )
        )
    }
}

private extension RTCClient {
    func negotiate(role negotiationRole: NegotiationRole, peerConnection: PeerConnection) async throws {
        switch negotiationRole {
        case .initiator: try await negotiateAsInitator(peerConnection: peerConnection)
        case .answerer: try await negotiateAsAnswerer(peerConnection: peerConnection)
        }
    }
    
    func negotiateAsInitator(peerConnection: PeerConnection) async throws {
        debugPrint("👭 Negotiating as initiator 🥇")
        // Create `Offer` and set it locally
        debugPrint("☑️ Creating `Offer` and setting it locally...")
        let offer = try await peerConnection.offer()
        debugPrint("✅ Created `Offer` and set it locally.")
       
        // Send `Offer` to remote
        debugPrint("☑️ Sending `Offer` to remote...")
        try await signaling.sendToRemote(.offer(offer))
        debugPrint("✅ Sent `Offer` to remote.")
        
        // Receive `Answer` from remote
        debugPrint("☑️ Waiting for `Answer` from remote...")
        for await answer in signaling
            .receiveFromRemoteAsyncSequence()
            .compactMap({ $0.answer })
            .prefix(1)
        {
            debugPrint("✅ Got `Answer` from remote.")
            // Set `Answer`
            debugPrint("☑️ Setting `Answer` from remote...")
            try await peerConnection.setRemoteAnswer(answer)
            debugPrint("✅ Set `Answer` from remote.")
            break
        }
        // done
        debugPrint("👭 Negotiation finished 🥇✅.")
    }
    func negotiateAsAnswerer(peerConnection: PeerConnection) async throws {
        debugPrint("👭 Negotiating as answerer 🥈")
        // Receive `Offer` from remote
        debugPrint("☑️ Waiting for `Offer` from remote...")
        for await offer in signaling
            .receiveFromRemoteAsyncSequence()
            .compactMap({ $0.offer })
            .prefix(1)
        {
            debugPrint("✅ Got `Offer` from remote.")
            // Set `Offer`
            debugPrint("☑️ Setting `Offer` from remote...")
            try await peerConnection.setRemoteOffer(offer)
            debugPrint("✅ Set `Offer` from remote.")
            break
        }
        // Create `Answer` and set it locally
        debugPrint("☑️ Creating `Answer` and setting it locally...")
        let answer = try await peerConnection.answer()
        debugPrint("✅ Created `Answer` and set it locally.")
        
        // Send `Answer` to remote
        debugPrint("☑️ Sending `Answer` to remote...")
        try await signaling.sendToRemote(.answer(answer))
        debugPrint("✅ Sent `Answer` to remote.")
        // done
        debugPrint("👭 Negotiation finished 🥈✅.")
    }
}
