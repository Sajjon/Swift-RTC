//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-30.
//

import AsyncExtensions
import Foundation
import RTCModels

// MARK: Packer
public extension SignalingClient {
    struct Packer<T: Sendable>: Sendable {
        public typealias Pack = @Sendable (SignalingServerMessage) async throws -> T
        public var pack: Pack
        public init(pack: @escaping Pack) {
            self.pack = pack
        }
    }
}


// MARK: Unpacker
public extension SignalingClient {
    struct Unpacker<T: Sendable>: Sendable {
        public typealias Unpack = @Sendable (T) async throws -> SignalingServerMessage
        public var unpack: Unpack
        public init(unpack: @escaping Unpack) {
            self.unpack = unpack
        }
    }
}

public extension SignalingClient.Unpacker where T == Data {
    static var json: Self {
        .init(unpack: { try JSONDecoder().decode(SignalingServerMessage.self, from: $0) })
    }
}

public extension SignalingClient.Packer where T == Data {
    static var json: Self {
        .init(pack: { try JSONEncoder().encode($0) })
    }
}

// MARK: Transport
public extension SignalingClient {
    typealias Transport<ID: Sendable & Hashable, InOutMessage: Sendable & Equatable> = Tunnel<ID, Never, InOutMessage, InOutMessage>
}

public extension SignalingClient {
    
    static func with<ID, Message>(
        packer: Packer<Message>,// = .json,
        unpacker: Unpacker<Message>,// = .json,
        transport: Transport<ID, Message>
    ) -> Self
    where ID: Sendable & Hashable, Message: Sendable & Hashable
    {
        let multicastSubject = AsyncThrowingPassthroughSubject<SignalingServerMessage, Error>()
        let (stream, continuation) = AsyncStream.streamWithContinuation(SignalingServerMessage.self)
        
        return Self(
            sendToRemote: { rtcPrimitive in
                let data = try await packer.pack(rtcPrimitive)
                try await transport.send(data)
            },
            receiveFromRemoteAsyncSequence: {
                Task {
                    for try await data in try await transport.incomingMessages() {
                        try Task.checkCancellation()
                        let signalingServerMessage = try await unpacker.unpack(data)
                        continuation.yield(signalingServerMessage)
                    }
                }
                return stream
                    .multicast(multicastSubject)
                    .autoconnect()
                    .eraseToAnyAsyncSequence()
            }
        )
    }
}

