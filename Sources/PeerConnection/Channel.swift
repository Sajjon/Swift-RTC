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
   
    public let connectionStatusAsyncSequence: AsyncStream<DataChannelState>
    private let connectionStatusAsyncContinuation: AsyncStream<DataChannelState>.Continuation
    
    init(
        id: DataChannelID,
        dataChannel: RTCDataChannel
    ) {
        self.id = id
        self.dataChannel = dataChannel
        (incomingMessageAsyncSequence, incomingMessageAsyncContinuation) = AsyncStream.streamWithContinuation(Data.self)
        
        (connectionStatusAsyncSequence, connectionStatusAsyncContinuation) = AsyncStream.streamWithContinuation(DataChannelState.self)
    }
}

// MARK: Internal
internal extension Channel {
    func received(data: Data) {
        incomingMessageAsyncContinuation.yield(data)
    }
    func updateConnectionStatus(_ newStatus: DataChannelState) {
        connectionStatusAsyncContinuation.yield(newStatus)
    }
}

// MARK: Public
public extension Channel {
    func send(data: Data) {
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
