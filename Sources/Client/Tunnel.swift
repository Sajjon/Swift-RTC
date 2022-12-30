//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-30.
//

import AsyncExtensions
import Foundation
import RTCModels
import RTCPeerConnection

public struct Tunnel<Message>: Sendable where Message: Sendable & Equatable{
    public var push: Push
    public var subscribeToReadyState: SubscribeToReadyState
    public var subscribeToIncomingMessages: SubscribeToIncomingMessages
    public var close: Close
    
    public init(
        push: @escaping Push,
        subscribeToReadyState: @escaping SubscribeToReadyState,
        subscribeToIncomingMessages: @escaping SubscribeToIncomingMessages,
        close: @escaping Close
    ) {
        self.push = push
        self.subscribeToReadyState = subscribeToReadyState
        self.subscribeToIncomingMessages = subscribeToIncomingMessages
        self.close = close
    }
}

public extension Tunnel {
    typealias ReadyState = DataChannelState
    typealias Push = @Sendable (Message) async throws -> Void
    
    typealias SubscribeToReadyState = @Sendable () async throws ->
    AnyAsyncSequence<ReadyState>
    typealias SubscribeToIncomingMessages = @Sendable () async throws ->
    AnyAsyncSequence<Message>
    typealias Close = @Sendable () async throws -> Void
}

public extension Tunnel<Data>.Encoder {
    static let passthrough: Self = {
        Self(encode: { $0 })
    }()
}
public extension Tunnel<Data>.Decoder {
    static let passthrough: Self = {
        Self(decode: { $0 })
    }()
}

public extension Tunnel {
    struct Encoder: Sendable {
        public typealias Encode = @Sendable (Message) async throws -> Data
        public var encode: Encode
        public init(encode: @escaping Encode) {
            self.encode = encode
        }
    }
    struct Decoder: Sendable {
        public typealias Decode = @Sendable (Data) async throws -> Message
        public var decode: Decode
        public init(decode: @escaping Decode) {
            self.decode = decode
        }
    }
    static func live(
        channel: Channel,
        encoder: Encoder,
        decoder: Decoder
    ) -> Self {
        
        let readyStateMulticastSubject = AsyncThrowingPassthroughSubject<ReadyState, Error>()
        let messagesMulticastSubject = AsyncThrowingPassthroughSubject<Message, Error>()
        let (readyStateAsyncSequence, readyStateAsyncContinuation) = AsyncStream.streamWithContinuation(DataChannelState.self)
        let (inMessagesAsyncSequence, inMessagesAsyncContinuation) = AsyncStream.streamWithContinuation(Message.self)

        let task = Task {
            await withThrowingTaskGroup(of: Void.self) { group in
                _ = group.addTaskUnlessCancelled {
                    for await readyState in await channel.readyStateAsyncSequence {
                        try Task.checkCancellation()
                        readyStateAsyncContinuation.yield(readyState)
                    }
                }
                
                _ = group.addTaskUnlessCancelled {
                    for await data in await channel.incomingMessageAsyncSequence {
                        try Task.checkCancellation()
                        let message = try await decoder.decode(data)
                        inMessagesAsyncContinuation.yield(message)
                    }
                }
            }
        }
        
        return Self(
            push: { message in
                let data = try await encoder.encode(message)
                try await channel.send(data: data)
            },
            subscribeToReadyState: {
                readyStateAsyncSequence
                    .multicast(readyStateMulticastSubject)
                    .autoconnect()
                    .eraseToAnyAsyncSequence()
            },
            subscribeToIncomingMessages: {
                 inMessagesAsyncSequence
                    .multicast(messagesMulticastSubject)
                    .autoconnect()
                    .eraseToAnyAsyncSequence()
            },
            close: {
                task.cancel()
                await channel.disconnect()
            }
        )
    }
}
