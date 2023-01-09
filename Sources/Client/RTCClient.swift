//
//  File.swift
//
//
//  Created by Alexander Cyon on 2022-12-28.
//

import MessageSplitter
import MessageAssembler
import P2PPeerConnection
import SignalingServerClient
import Tunnel

public actor RTCClient {
    typealias Connections = Disposables<PeerConnection>
    private let signaling: SignalingClient
    private let connections: Connections = .init()
    private let source: ClientSource

    public init(
        signaling: SignalingClient,
        source: ClientSource
    ) {
        self.signaling = signaling
        self.source = source
    }
}

/// An envelop for an application layer message to split or that was reassembled,
/// containing the lower level split/reassemble protocol MessageID which is used
/// to send message received receipts for incoming **application layer messages** or
/// to use in order to confirm that outgoing messages was correcly received by
/// remote peer by checking incoming message for confirmation receipts matching the id.
public struct SplitOrReassembledEnvelop<Message: Sendable & Hashable>: Sendable, Hashable {
    /// The application layer message to split or that was reassembled
    public let message: Message

    /// The ID of the chunks the message was split into or reassembled from.
    public let idsOfChunks: ChunkedMessagePackage.MessageID
}

public extension RTCClient {
    
    typealias RadixTunnel = Tunnel<DataChannelID, DataChannelState, SplitOrReassembledEnvelop<ToWallet>, SplitOrReassembledEnvelop<FromWallet>>
    
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

    actor FilterActor: GlobalActor {
        public static let shared = FilterActor()
        private var receivedMessagesByContentHash: Set<Data> = .init()
        
        /// returns `false` if this message should not be propagated to the application layer, otherwise `true`.
        public func filter(_ assembledMessage: AssembledMessage) -> Bool {
            guard !receivedMessagesByContentHash.contains(assembledMessage.messageHash) else {
                return false
            }
            receivedMessagesByContentHash.insert(assembledMessage.messageHash)
            return true
        }
    }
    
    /// Create a new tunnel using MessageSplitter and Reassembler, for sending
    ///
    /// This function will create a new `PeerConnection` if no current connection matching
    /// the `peerConnectionID` exists.
    ///
    /// Decoded messages using MessageAssembler can be filtered by `filter`, by default
    /// we do filter, you can opt out of this by specifying `filter: nil`, filtering is useful
    /// when e.g. the Connector extension is resending messages if this client does not send
    /// message received confirmation, we can thus prevent the same request from being displayed
    /// twice if we filter it (protecting from potential bug somewhere in Connector Extension or this
    /// client, in best of worlds the send message received confirmation logic should work).
    func newTunnel(
        id dataChannelID: DataChannelID,
        config: Config,
        filter: (@Sendable (AssembledMessage) async throws -> Bool)? = { await FilterActor.shared.filter($0) }
    ) async throws -> RadixTunnel {
        let peerConnectionID = config.connectionSecrets.connectionID
        if await connections.containsID(peerConnectionID) == false {
            try await newConnection(id: peerConnectionID, config: config.webRTC, negotiationRole: config.negotiationRole)
        }
        let jsonEncoder = JSONEncoder()
        let jsonDecoder = JSONDecoder()
        let messageSplitter = MessageSplitter()
    
        actor ChunkReceiver: GlobalActor {
            let messageAssembler = MessageAssembler()
            private var packagesByMsgID: [ChunkedMessagePackage.MessageID: [ChunkedMessagePackage]] = [:]
            static let shared = ChunkReceiver()
            func receive(packageChunk package: ChunkedMessagePackage) throws -> AssembledMessage? {
                let id = package.messageId
                guard
                    let packages = packagesByMsgID[id],
                    let assembled = try? messageAssembler.assemble(packages: packages)
                else {
                    packagesByMsgID[id] = [package]
                    return nil
                }
               return assembled
            }
        }
        
        return try await newTunnel(
            peerConnectionID: peerConnectionID,
            channelID: dataChannelID,
            config: config.dataChannel,
            encoder: .init(encode: { envelop in
                let toDapp = envelop.message
                let json = try jsonEncoder.encode(toDapp)
                let chunks = try messageSplitter.split(message: json, messageID: .init())
                return try chunks.map { try jsonEncoder.encode($0) }
            }),
            decoder: .init(decode: { data -> SplitOrReassembledEnvelop<ToWallet>? in
                let chunk = try jsonDecoder.decode(ChunkedMessagePackage.self, from: data)
                guard let assembled = try await ChunkReceiver.shared.receive(packageChunk: chunk) else {
                    return nil
                }
                let toWallet = try jsonDecoder.decode(ToWallet.self, from: assembled.messageContent)
                let envelop = SplitOrReassembledEnvelop<ToWallet>(message: toWallet, idsOfChunks: assembled.idOfChunks)
                guard let filter else {
                    return envelop
                }
                guard try await filter(assembled) else {
                    return nil
                }
                return envelop
            })
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

        @Sendable func reconnect(triggeredBy _: RTCEvent) {
            // I think we should use `detatched` since caller of this might be in a Task which gets cancelled by
            // the reconnect, effecively cancelling this reconnect? However, `detatched` might bypass that?
            Task.detached(priority: .high) { [unowned self] in
                await self.connections.cancelDisconnectAndRemove(id: id)
                try await self.newConnection(id: id, config: config, negotiationRole: negotiationRole)
            }
        }

        let connectTask = Task {
            await withThrowingTaskGroup(of: Void.self) { group in

                // RECONNECT by WebRTC events
                _ = group.addTaskUnlessCancelled {
                    try Task.checkCancellation()
                    for await iceConnectionState in peerConnection.iceConnectionStateAsyncSequence {
                        guard !Task.isCancelled else { return }
                        guard config.eventsTriggeringReconnect.iceConnectionStates.contains(iceConnectionState) else {
                            continue
                        }
                        reconnect(triggeredBy: .webRTC(.iceConnectionState(iceConnectionState)))
                    }
                }

                // RECONNECT by Signaling events - we probably dont want this?
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    try Task.checkCancellation()
                    if let sipEvents = await self.signaling.sessionInitiationProtocolEventsAsyncSequence?() {
                        for try await sipEvent in sipEvents {
                            guard !Task.isCancelled else { return }
                            guard config.eventsTriggeringReconnect.sipEvents.contains(sipEvent) else {
                                continue
                            }
                            reconnect(triggeredBy: .sessionInitiationProtocolEvent(sipEvent))
                        }
                    }
                }

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
                        debugPrint("❄️ \(source): Generated new ICE candidate, sending to remote...")
                        try await self.signaling.sendToRemote(primitive: .addICE(ice))
                        debugPrint("❄️ \(source): Sent newly generated ICE candidate to remote")
                    }
                }

                _ = group.addTaskUnlessCancelled { [unowned self] in
                    // remote ICE to local
                    try Task.checkCancellation()
                    for try await ice in await self.signaling
                        .rtcPrimitivesFromRemoteAsyncSequence()
                        .compactMap({ $0.addICE })
                        .prefix(1)
                    {
                        debugPrint("❄️ \(source): Received ICE from remote")
                        try await peerConnection.addRemoteICE(ice)
                        debugPrint("❄️ \(source): Set ICE from remote.")
                        break
                    }
                }

                // REMOVE ICE
                _ = group.addTaskUnlessCancelled { [unowned self] in
                    // local ICE to remove from remote
                    try Task.checkCancellation()
                    for await ices in peerConnection.removeICECandidatesAsyncSequence {
                        guard !Task.isCancelled else { return }
                        try await self.signaling.sendToRemote(primitive: .removeICEs(ices))
                    }
                }

                _ = group.addTaskUnlessCancelled { [unowned self] in
                    // remote ICEs to remove locally
                    try Task.checkCancellation()
                    for try await icesToRemove in await self.signaling
                        .rtcPrimitivesFromRemoteAsyncSequence()
                        .compactMap({ $0.removeICEs })
                        .prefix(1)
                    {
                        debugPrint("❄️ \(source): Received ICEs to remove from remote")
                        await peerConnection.removeICECandidates(icesToRemove)
                        debugPrint("❄️ \(source): Removed ICEs locally.")
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
        debugPrint("👭 \(source): Negotiating as initiator 🥇")
        // Create `Offer` and set it locally
        debugPrint("☑️ \(source): Creating `Offer` and setting it locally...")
        let offer = try await peerConnection.offer()
        debugPrint("✅ \(source): Created `Offer` and set it locally.")

        // Send `Offer` to remote
        debugPrint("☑️ \(source): Sending `Offer` to remote...")
        try await signaling.sendToRemote(primitive: .offer(offer))
        debugPrint("✅ \(source): Sent `Offer` to remote.")

        // Receive `Answer` from remote
        debugPrint("☑️ \(source): Waiting for `Answer` from remote...")
        for try await answer in await signaling
            .rtcPrimitivesFromRemoteAsyncSequence()
            .compactMap({ $0.answer })
            .prefix(1)
        {
            debugPrint("✅ \(source): Got `Answer` from remote.")
            // Set `Answer`
            debugPrint("☑️ \(source): Setting `Answer` from remote...")
            try await peerConnection.setRemoteAnswer(answer)
            debugPrint("✅ \(source): Set `Answer` from remote.")
            break
        }
        // done
        debugPrint("👭 \(source): Negotiation finished 🥇✅.")
    }

    func negotiateAsAnswerer(peerConnection: PeerConnection) async throws {
        debugPrint("👭 \(source): Negotiating as answerer 🥈")
        // Receive `Offer` from remote
        debugPrint("☑️ \(source): Waiting for `Offer` from remote...")
        for try await offer in await signaling
            .rtcPrimitivesFromRemoteAsyncSequence()
            .compactMap({ $0.offer })
            .prefix(1)
        {
            debugPrint("✅ \(source): Got `Offer` from remote.")
            // Set `Offer`
            debugPrint("☑️ \(source): Setting `Offer` from remote...")
            try await peerConnection.setRemoteOffer(offer)
            debugPrint("✅ \(source): Set `Offer` from remote.")
            break
        }
        // Create `Answer` and set it locally
        debugPrint("☑️ \(source): Creating `Answer` and setting it locally...")
        let answer = try await peerConnection.answer()
        debugPrint("✅ \(source): Created `Answer` and set it locally.")

        // Send `Answer` to remote
        debugPrint("☑️ \(source): Sending `Answer` to remote...")
        try await signaling.sendToRemote(primitive: .answer(answer))
        debugPrint("✅ \(source): Sent `Answer` to remote.")
        // done
        debugPrint("👭 \(source): Negotiation finished 🥈✅.")
    }
}

