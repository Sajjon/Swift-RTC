//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-30.
//

import AsyncExtensions
import Foundation
import RTCModels


public extension Tunnel where ReadyState == DataChannelState {
    static func live(
        channel: Channel,
        encoder: Encoder,
        decoder: Decoder
    ) -> Self {
        
        let readyStateMulticastSubject = AsyncThrowingPassthroughSubject<ReadyState, Error>()
        let (readyStateAsyncSequence, readyStateAsyncContinuation) = AsyncStream.streamWithContinuation(DataChannelState.self)
       
        let incomingMessagesMulticastSubject = AsyncThrowingPassthroughSubject<IncomingMessage, Error>()
        let (inMessagesAsyncSequence, inMessagesAsyncContinuation) = AsyncStream.streamWithContinuation(IncomingMessage.self)
        
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
            readyStateUpdates: {
                readyStateAsyncSequence
                    .multicast(readyStateMulticastSubject)
                    .autoconnect()
                    .eraseToAnyAsyncSequence()
            },
            incomingMessages: {
                 inMessagesAsyncSequence
                    .multicast(incomingMessagesMulticastSubject)
                    .autoconnect()
                    .eraseToAnyAsyncSequence()
            },
            send: { message in
                let data = try await encoder.encode(message)
                try await channel.send(data: data)
            },
            close: {
                task.cancel()
                await channel.disconnect()
            }
        )
    }
}
