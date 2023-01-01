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
    /// Throws an error if no `PeerConnection` matching the `peerConnectionID`
    func disconnectChannel(
        id channelID: DataChannelID,
        peerConnectionID: PeerConnectionID
    ) async throws {
        let peerConnection = try await connections.get(id: peerConnectionID)
        await peerConnection.closeChannel(id: channelID)
    }

    /// Disconnects, cancels and removes the `PeerConnection` with `PeerConnectionID` of `id` if present.
    func disconnectPeerConnection(id: PeerConnectionID) async {
        await connections.cancelDisconnectAndRemove(id: id)
    }

    /// Throws an error if no `PeerConnection` matching the `peerConnectionID`
    /// exists.
    func newTunnel<InMsg, OutMsg>(
        peerConnectionID: PeerConnectionID,
        channelID: DataChannelID,
        config: DataChannelConfig,
        encoder: Tunnel<DataChannelID, DataChannelState, InMsg, OutMsg>.Encoder,
        decoder: Tunnel<DataChannelID, DataChannelState, InMsg, OutMsg>.Decoder
    ) async throws -> Tunnel<DataChannelID, DataChannelState, InMsg, OutMsg> {
        // Create a new RTCDataChannel, wrapped in a `Tunnel`
        let tunnel = try await newChannel(
            peerConnectionID: peerConnectionID,
            channelID: channelID,
            config: config
        )

        // Create a new Application Layer `Tunnel` which encodes/decodes messages using
        // `encoder` and `decoder`.
        return Tunnel.live(
            tunnel: tunnel,
            encoder: encoder,
            decoder: decoder
        )
    }

    /// Creates a new `PeerConnection` with `PeerConnectionID` of `id` as `negotiationRole` using
    /// `config` as `WebRTCConfig`.
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

                // // RECONNECT
                // _ = group.addTaskUnlessCancelled { [unowned self] in
                //     try Task.checkCancellation()
                //     for await iceConnectionState in peerConnection.iceConnectionStateAsyncSequence {
                //         guard !Task.isCancelled else { return }

                //     }
                // }

                // NEGOTIATION
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    for await negotiationRole in peerConnection.shouldNegotiateAsyncSequence {
                        guard !Task.isCancelled else { return }
                        try await self.negotiate(role: negotiationRole, peerConnection: peerConnection)
                    }
                }

                // ICE Exchange
                // ADD ICE
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    // local ICE to remote
                    try Task.checkCancellation()
                    for await ice in peerConnection.generatedICECandidateAsyncSequence {
                        guard !Task.isCancelled else { return }
                        debugPrint("❄️ Generated new ICE candidate, sending to remote...")
                        try await self.signaling.sendToRemote(.addICE(ice))
                        debugPrint("❄️ Sent newly generated ICE candidate to remote")
                    }
                }
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    // remote ICE to local
                    try Task.checkCancellation()
                    for try await ice in self.signaling
                        .receiveFromRemoteAsyncSequence()
                        .compactMap({ $0.addICE })
                        .prefix(1)
                    {
                        debugPrint("❄️ Received ICE from remote")
                        try await peerConnection.addRemoteICE(ice)
                        debugPrint("❄️ Set ICE from remote.")
                        break
                    }
                }

                // REMOVE ICE
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    // local ICE to remove from remote
                    try Task.checkCancellation()
                    for await ices in peerConnection.removeICECandidatesAsyncSequence {
                        guard !Task.isCancelled else { return }
                        try await self.signaling.sendToRemote(.removeICEs(ices))
                    }
                }

                _ = group.addTaskUnlessCancelled { [unowned self] in
                    // remote ICEs to remove locally
                    try Task.checkCancellation()
                    for try await icesToRemove in self.signaling
                        .receiveFromRemoteAsyncSequence()
                        .compactMap({ $0.removeICEs })
                        .prefix(1)
                    {
                        debugPrint("❄️ Received ICEs to remove from remote")
                        await peerConnection.removeICECandidates(icesToRemove)
                        debugPrint("❄️ Removed ICEs locally.")
                        break
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

// MARK: Internal

internal extension RTCClient {
    /// Throws an error if no `PeerConnection` matching the `peerConnectionID`
    /// exists.
    func newChannel(
        peerConnectionID: PeerConnectionID,
        channelID: DataChannelID,
        config: DataChannelConfig
    ) async throws -> Tunnel<DataChannelID, DataChannelState, Data, Data> {
        let peerConnection = try await connections.get(id: peerConnectionID)
        return try await peerConnection.newChannel(id: channelID, config: config)
    }
}

// MARK: Private

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
        for try await answer in signaling
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
        for try await offer in signaling
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
