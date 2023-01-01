//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-30.
//

import AsyncExtensions
import Foundation
import RTCModels


public extension Tunnel where ID == DataChannelID, ReadyState == DataChannelState {
    static func live(
        tunnel: Tunnel<DataChannelID, DataChannelState, Data, Data>,
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
                    for try await readyState in try await tunnel.readyStateUpdates() {
                        try Task.checkCancellation()
                        readyStateAsyncContinuation.yield(readyState)
                    }
                }
                
                _ = group.addTaskUnlessCancelled {
                    for try await data in try await tunnel.incomingMessages() {
                        try Task.checkCancellation()
                        let message = try await decoder.decode(data)
                        inMessagesAsyncContinuation.yield(message)
                    }
                }
            }
        }
        
        return Self.live(
            getID: tunnel.id,
            readyStateAsyncStream: readyStateAsyncSequence,
            incomingMessagesAsyncStream: inMessagesAsyncSequence,
            send: { message in
                let data = try await encoder.encode(message)
                try await tunnel.send(data)
            },
            close: {
                task.cancel()
                await tunnel.disconnect()
            }
        )
    }
}
