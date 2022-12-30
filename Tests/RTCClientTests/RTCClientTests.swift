//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import AsyncExtensions
import Foundation
@testable import RTCClient
import RTCModels
import RTCPeerConnection
import RTCSignaling
import XCTest


final class RTCClientTests: XCTestCase {
    
    
    func test_session() async throws {

        let initiatorReceivedMsgExp = expectation(description: "Initiator received msg")
        let answererReceivedMsgExp = expectation(description: "Answerer received msg")
        
        let (signalingToInitiatorAsyncSequence, signalingToInitiatorAsyncContinuation) = AsyncStream.streamWithContinuation(RTCPrimitive.self)
        let (signalingToAnswererAsyncSequence, signalingToAnswererAsyncContinuation) = AsyncStream.streamWithContinuation(RTCPrimitive.self)
        
        let initiatorSignalingMulticastSubject = AsyncThrowingPassthroughSubject<RTCPrimitive, Error>()
        let initiatorSignaling = SignalingClient(
            sendToRemote: { signalingToAnswererAsyncContinuation.yield($0 )},
            receiveFromRemoteAsyncSequence: {
                signalingToInitiatorAsyncSequence
                .multicast(initiatorSignalingMulticastSubject)
                .autoconnect()
                .eraseToAnyAsyncSequence()
                
            }
        )
        
        let answererSignalingMulticastSubject = AsyncThrowingPassthroughSubject<RTCPrimitive, Error>()
        let answererSignaling = SignalingClient(
            sendToRemote: { signalingToInitiatorAsyncContinuation.yield($0) },
            receiveFromRemoteAsyncSequence: {
                signalingToAnswererAsyncSequence
                .multicast(answererSignalingMulticastSubject)
                .autoconnect()
                .eraseToAnyAsyncSequence() }
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
        let dcConfig: DataChannelConfig = .init(isOrdered: true, isNegotiated: true)
        let initiatorToAnswererChannel = try await initiator.newChannel(
            peerConnectionID: pcID,
            channelID: dcID,
            config: dcConfig
        )
        let answererToInitiatorChannel = try await answerer.newChannel(
            peerConnectionID: pcID,
            channelID: dcID,
            config: dcConfig
        )
        
        
        let initiatorConnectedToAnswerer = Task {
            let _ = await initiatorToAnswererChannel.connectionStatusAsyncSequence.first(where: { $0 == .open })
        }

        let answererConnectedToInitiator = Task {
            let _ = await answererToInitiatorChannel.connectionStatusAsyncSequence.first(where: { $0 == .open })
        }
        let _ = (await initiatorConnectedToAnswerer.value, await answererConnectedToInitiator.value)

        Task {
            for await msg in await initiatorToAnswererChannel.incomingMessageAsyncSequence.prefix(1) {
                XCTAssertEqual(msg, Data("Hey Initiator".utf8), "Got unexpected: '\(String(data: msg, encoding: .utf8)!)'")
                initiatorReceivedMsgExp.fulfill()
            }
        }

        Task {
            for await msg in await answererToInitiatorChannel.incomingMessageAsyncSequence.prefix(1) {
                XCTAssertEqual(msg, Data("Hey Answerer".utf8), "Got unexpected: '\(String(data: msg, encoding: .utf8)!)'")
                answererReceivedMsgExp.fulfill()
            }
        }
        
        Task {
            await initiatorToAnswererChannel.send(data: Data("Hey Answerer".utf8))
        }

        Task {
            await answererToInitiatorChannel.send(data: Data("Hey Initiator".utf8))
        }

        await waitForExpectations(timeout: 3)
    }
}
