//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import Foundation
import WebRTC
import RTCModels

public actor Channel: Disconnecting {
    
    public let id: DataChannelID
    internal let dataChannel: RTCDataChannel
    
    public let incomingMessageAsyncSequence: AsyncStream<Data>
    private let incomingMessageAsyncContinuation: AsyncStream<Data>.Continuation
   
    public let readyStateAsyncSequence: AsyncStream<DataChannelState>
    private let readyStateAsyncContinuation: AsyncStream<DataChannelState>.Continuation

    init(
        id: DataChannelID,
        dataChannel: RTCDataChannel
    ) {
        self.id = id
        self.dataChannel = dataChannel
        (incomingMessageAsyncSequence, incomingMessageAsyncContinuation) = AsyncStream.streamWithContinuation(Data.self)
        
        (readyStateAsyncSequence, readyStateAsyncContinuation) = AsyncStream.streamWithContinuation(DataChannelState.self)
    }
}

// MARK: Internal
internal extension Channel {
    func received(data: Data) {
        incomingMessageAsyncContinuation.yield(data)
    }
    func updateReadyState(_ newStatus: DataChannelState) {
        readyStateAsyncContinuation.yield(newStatus)
    }
}

// MARK: Public
public extension Channel {
    
    enum Error: String, LocalizedError, Sendable {
        case channelIsNotOpen
    }
    
    func send(data: Data) throws {
        guard dataChannel.readyState == .open else {
            throw Error.channelIsNotOpen
        }
        dataChannel.sendData(.init(data: data, isBinary: true))
    }
}

// MARK: Disconnecting
public extension Channel {
    func disconnect() async {
        dataChannel.delegate = nil
        dataChannel.close()
    }
}

// MARK: Equatable
public extension Channel {
    static func == (lhs: Channel, rhs: Channel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: Hashable
public extension Channel {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
