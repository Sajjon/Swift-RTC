//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation
import WebRTC
import P2PModels

internal final class DataChannelDelegate: NSObject, RTCDataChannelDelegate, Sendable {
    
    let peerConnectionID: PeerConnectionID
    let dataChannelID: DataChannelID

    internal let messageReceivedAsyncSequence: AsyncStream<Data>
    private let messageReceivedAsyncContinuation: AsyncStream<Data>.Continuation
    
    internal let readyStateAsyncSequence: AsyncStream<DataChannelState>
    private let readyStateAsyncContinuation: AsyncStream<DataChannelState>.Continuation
    
    internal init(peerConnectionID: PeerConnectionID, dataChannelID: DataChannelID) {
        self.peerConnectionID = peerConnectionID
        self.dataChannelID = dataChannelID
        
        
        (messageReceivedAsyncSequence, messageReceivedAsyncContinuation) = AsyncStream.streamWithContinuation(Data.self)
        
        (readyStateAsyncSequence, readyStateAsyncContinuation) = AsyncStream.streamWithContinuation(DataChannelState.self)
        
        super.init()
    }
    
}


// MARK: RTCDataChannelDelegate
internal extension DataChannelDelegate {
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        debugPrint("peerConnection id: \(peerConnectionID), dataChannel=\(dataChannel.channelId) didReceiveMessageWith #\(buffer.data.count) bytes")
        let id = DataChannelID(label: dataChannel.label)
        guard id == dataChannelID else { fatalError("id mismatch") }
        messageReceivedAsyncContinuation.yield(buffer.data)
    }
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let readyState = dataChannel.readyState.swiftify()
        debugPrint("peerConnection id: \(peerConnectionID), dataChannel=\(dataChannel.channelId) dataChannelDidChangeState to: \(readyState)")
        let id = DataChannelID(label: dataChannel.label)
        guard id == dataChannelID else { fatalError("id mismatch") }
        readyStateAsyncContinuation.yield(readyState)
    }
}

