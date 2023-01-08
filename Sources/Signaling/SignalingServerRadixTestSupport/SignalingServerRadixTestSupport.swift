//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation
import SignalingServerClient
import P2PModels
import SignalingServerRadix
import Tunnel

// MARK: Encoder Passthrough
public extension Tunnel.Encoder where Tunnel.In == Data, Tunnel.Out == Data {
    static var passthrough: Self {
        Self(encode: { $0 })
    }
}

// MARK: Decoder Passthrough
public extension Tunnel.Decoder where Tunnel.In == Data, Tunnel.Out == Data {
    static var passthrough: Self {
        Self(decode: { $0 })
    }
}

#if DEBUG
public extension SignalingClient.Transport {


    static func multicastPassthrough<IncomingMessagesAsync>(
        incoming: IncomingMessagesAsync,
        send: @escaping Send,
        close: Close? = { print("closed called") }
    ) -> Self where   IncomingMessagesAsync: AsyncSequence & Sendable,
                      IncomingMessagesAsync.AsyncIterator: Sendable,
                      IncomingMessagesAsync.Element == IncomingMessage {
        Self.multicast(
            getID: { fatalError("No ID") }(),
            readyStateAsyncSequence: AsyncStream(unfolding: { fatalError("No ready state") }),
            incomingMessagesAsyncSequence: incoming,
            send: send,
            close: { await close?() }
        )
    }
}

// MARK: SignalingClient
public extension SignalingClient {
    static func passthrough(
        transport: Transport,
        connectionID: PeerConnectionID = .placeholder,
        jsonEncoder: JSONEncoder = .init(),
        source: ClientSource,
        requireMessageSentConfirmationFromSignalingServerWhenSending: Bool = false,
        requestId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) -> Self {
        Self.radix(
            packer: .jsonEncodeOnly(
                connectionID: connectionID,
                jsonEncoder: jsonEncoder,
                source: source,
                requestId: requestId
            ),
            unpacker: .jsonDecodeOnly,
            transport: transport,
            requireMessageSentConfirmationFromSignalingServerWhenSending: requireMessageSentConfirmationFromSignalingServerWhenSending
        )
    }
}
#endif // DEBUG
