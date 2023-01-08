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


    static func multicastPassthrough(
        stream incomingMessagesAsyncStream: AsyncStream<Data>,
        continuation: AsyncStream<Data>.Continuation
    ) -> Self {
        Self.multicast(
            getID: { fatalError("No ID") }(),
            readyStateAsyncSequence: AsyncStream(unfolding: { fatalError("No ready state") }),
            incomingMessagesAsyncSequence: incomingMessagesAsyncStream,
            send: {
                continuation.yield($0)
            }, close: {
                continuation.finish()
            }
        )
    }
}

// MARK: SignalingClient
public extension SignalingClient {
    static func passthrough(
        stream: AsyncStream<Data>,
        continuation: AsyncStream<Data>.Continuation,
        connectionID: PeerConnectionID = .placeholder,
        jsonEncoder: JSONEncoder = .init(),
        source: ClientSource = .mobileWallet,
        requestId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) -> Self {
        Self.with(
            packer: .jsonEncodeOnly(connectionID: connectionID, jsonEncoder: jsonEncoder, source: source, requestId: requestId),
            unpacker: .jsonDecodeOnly,
            transport: .multicastPassthrough(stream: stream, continuation: continuation)
        )
    }
}
#endif // DEBUG
