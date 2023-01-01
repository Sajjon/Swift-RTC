//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation
import RTCPeerConnection
import RTCSignaling
import RTCModels

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

public extension SignalingClient.Packer where T == RTCPrimitive {
    static let passthrough = Self(pack: { $0 })
}

public extension SignalingClient.Unpacker where T == RTCPrimitive {
    static let passthrough = Self(unpack: { $0 })
}

public extension SignalingClient.Transport where ID == Never, IncomingMessage == OutgoingMessage {

    typealias InOutMessage = IncomingMessage

    static func multicastPassthrough(
        stream incomingMessagesAsyncStream: AsyncStream<InOutMessage>,
        continuation: AsyncStream<InOutMessage>.Continuation
    ) -> Self {
        Self.multicast(
            getID: fatalError("No ID"),
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
    static func passthrough(stream: AsyncStream<Data>, continuation: AsyncStream<Data>.Continuation) -> Self {
        Self.with(
            packer: .json,
            unpacker: .json,
            transport: .multicastPassthrough(stream: stream, continuation: continuation)
        )
    }
}
