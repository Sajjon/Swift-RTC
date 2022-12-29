//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import Foundation
import XCTest
@testable import RTCClient
import RTCSignaling
import RTCPeerConnection
import RTCModels

final class RTCClientTests: XCTestCase {
    
    
    
    func test_session() async throws {
        
        let msgSentByInitator = ActorIsolated<Data?>(nil)
        let msgSentByAnswerer = ActorIsolated<Data?>(nil)
        
        let (signalingToInitiatorAsyncSequence, signalingToInitiatorAsyncContinuation) = AsyncStream.streamWithContinuation(RTCPrimitive.self)
        let (signalingToAnswererAsyncSequence, signalingToAnswererAsyncContinuation) = AsyncStream.streamWithContinuation(RTCPrimitive.self)
        
        let initiatorSignaling = SignalingClient(
            sendToRemote: { signalingToAnswererAsyncContinuation.yield($0 )},
            receiveFromRemoteAsyncSequence: { signalingToInitiatorAsyncSequence }
        )
        
        let answererSignaling = SignalingClient(
            sendToRemote: { signalingToInitiatorAsyncContinuation.yield($0) },
            receiveFromRemoteAsyncSequence: { signalingToAnswererAsyncSequence }
        )
        
        let initiator = RTCClient(
            signaling: initiatorSignaling
        )
        
        let answerer = RTCClient(
            signaling: answererSignaling
        )
        let pcID: PeerConnectionID = 0
        try await initiator.newConnection(id: pcID, config: .default, negotiationRole: .initiator)
        try await answerer.newConnection(id: pcID, config: .default, negotiationRole: .answerer)
        
        let dcID: DataChannelID = 0

        let initiatorToAnswererChannel = try await initiator.newChannel(
            peerConnectionID: pcID,
            channelID: dcID,
            config: .default
        )
        let answererToInitiatorChannel = try await answerer.newChannel(
            peerConnectionID: pcID,
            channelID: dcID,
            config: .default
        )
        
        let initiatorConnectedToAnswerer = Task {
            let _ = await initiatorToAnswererChannel.connectionStatusAsyncSequence.first(where: { $0 == .open })
        }
        
        let answererConnectedToInitiator = Task {
            let _ = await answererToInitiatorChannel.connectionStatusAsyncSequence.first(where: { $0 == .open })
        }
        let _ = (await initiatorConnectedToAnswerer.value, await answererConnectedToInitiator.value)

        Task {
            await initiatorToAnswererChannel.send(data: Data("Hey Answerer".utf8))
        }
        
        Task {
            await answererToInitiatorChannel.send(data: Data("Hey Initiator".utf8))
        }
        
        Task {
            for await msg in await initiatorToAnswererChannel.incomingMessageAsyncSequence.prefix(1) {
                await msgSentByAnswerer.setValue(msg)
            }
        }
        
        Task {
            for await msg in await answererToInitiatorChannel.incomingMessageAsyncSequence.prefix(1) {
                await msgSentByInitator.setValue(msg)
            }
        }
        
        let msgFromInitator = await msgSentByInitator.value
        let msgFromAnswerer = await msgSentByAnswerer.value
        XCTAssertEqual(msgFromInitator, Data("Hey Answerer".utf8))
        XCTAssertEqual(msgFromAnswerer, Data("Hey Initiator".utf8))
        
        
//        let pc0NegotiationTriggered = expectation(description: "PeerConnection 0 triggered negotiateion")
//        let pc1NegotiationTriggered = expectation(description: "PeerConnection 1 triggered negotiateion")

//        let pc1 = try PeerConnection(
//            id: 1,
//            config: .default,
//            negotiationRole: .answerer
//        )
//
//        Task {
//            for await _ in pc0.shouldNegotiateAsyncSequence.prefix(1) {
//                pc0NegotiationTriggered.fulfill()
//            }
//        }
//
//        Task {
//            for await _ in pc1.shouldNegotiateAsyncSequence.prefix(1) {
//                pc1NegotiationTriggered.fulfill()
//            }
//        }
//
//
//        let channelID: DataChannelID = 0
//        let channelConfig: DataChannelConfig = .default
//        try await pc0.newChannel(id: channelID, config: channelConfig)
//        try await pc1.newChannel(id: channelID, config: channelConfig)
//
//        await waitForExpectations(timeout: 3)
        
    }
}
