//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-30.
//

import AsyncExtensions
import Foundation
import RTCModels

extension AsyncStream.Iterator: @unchecked Sendable where AsyncStream.Iterator.Element: Sendable {}

// MARK: Packer
public extension SignalingClient {
    struct Packer<T: Sendable>: Sendable {
        public typealias Pack = @Sendable (RTCPrimitive) async throws -> T
        public var pack: Pack
        public init(pack: @escaping Pack) {
            self.pack = pack
        }
    }
}

public extension SignalingClient.Packer where T == Data {
    static let json = Self.init(pack: { try JSONEncoder().encode($0) })
}

public extension SignalingClient.Packer where T == RTCPrimitive {
    static let passthrough = Self.init(pack: { $0 })
}

// MARK: Unpacker
public extension SignalingClient {
    struct Unpacker<T: Sendable>: Sendable {
        public typealias Unpack = @Sendable (T) async throws -> RTCPrimitive
        public var unpack: Unpack
        public init(unpack: @escaping Unpack) {
            self.unpack = unpack
        }
    }
}
public extension SignalingClient.Unpacker where T == Data {
    static let json = Self.init(unpack: { try JSONDecoder().decode(RTCPrimitive.self, from: $0) })
}

public extension SignalingClient.Unpacker where T == RTCPrimitive {
    static let passthrough = Self.init(unpack: { $0 })
}

// MARK: Transport
public extension SignalingClient {
    struct Transport<T: Sendable>: Sendable {
        public typealias Submit = @Sendable (T) async throws -> Void
        public typealias Subscribe = @Sendable () -> AsyncStream<T>
        public var submit: Submit
        public var subscribe: Subscribe
        public init(submit: @escaping Submit, subscribe: @escaping Subscribe) {
            self.submit = submit
            self.subscribe = subscribe
        }
    }
}

public extension SignalingClient.Transport {
    static func passthrough(stream: AsyncStream<T>, continuation: AsyncStream<T>.Continuation) -> Self {
        .init(submit: { continuation.yield($0) }, subscribe: { stream })
    }
}

// MARK: SignalingClient
public extension SignalingClient {
    static func passthrough(stream: AsyncStream<Data>, continuation: AsyncStream<Data>.Continuation) -> Self {
        Self.with(
            packer: .json,
            unpacker: .json,
            transport: .passthrough(stream: stream, continuation: continuation)
        )
    }
}

public extension SignalingClient {
 
    static func with<T>(
        packer: Packer<T> = .json,
        unpacker: Unpacker<T> = .json,
        transport: Transport<T>
    ) -> Self where T: Sendable {
        let multicastSubject = AsyncThrowingPassthroughSubject<RTCPrimitive, Error>()
        let (stream, continuation) = AsyncStream.streamWithContinuation(RTCPrimitive.self)

        return Self(
            sendToRemote: { rtcPrimitive in
                let data = try await packer.pack(rtcPrimitive)
                try await transport.submit(data)
            },
            receiveFromRemoteAsyncSequence: {
                Task {
                    for await data in transport.subscribe() {
                        try Task.checkCancellation()
                        let primitive = try await unpacker.unpack(data)
                        continuation.yield(primitive)
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
