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
        
        let (initiatorSignaling, answererSignaling) = SignalingClient.passthrough()
        
        let initiator = RTCClient(
            signaling: initiatorSignaling
        )
        
        let answerer = RTCClient(
            signaling: answererSignaling
        )
        let pcID: PeerConnectionID = 0
        let webRTCConfig: WebRTCConfig = .default
        try await initiator.newConnection(id: pcID, config: webRTCConfig, negotiationRole: .initiator)
        try await answerer.newConnection(id: pcID, config: webRTCConfig, negotiationRole: .answerer)
        
        let dcID: DataChannelID = 0
        let dcConfig: DataChannelConfig = .default
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
            let _ = await initiatorToAnswererChannel.readyStateAsyncSequence.first(where: { $0 == .open })
        }

        let answererConnectedToInitiator = Task {
            let _ = await answererToInitiatorChannel.readyStateAsyncSequence.first(where: { $0 == .open })
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
            try await initiatorToAnswererChannel.send(data: Data("Hey Answerer".utf8))
        }

        Task {
            try await answererToInitiatorChannel.send(data: Data("Hey Initiator".utf8))
        }

        await waitForExpectations(timeout: 3)
        
        try await initiator.disconnectChannel(id: dcID, peerConnectionID: pcID)
        do {
            try await initiatorToAnswererChannel.send(data: Data("This message should never reach answerer.".utf8))
            XCTFail("Expected to fail when trying to send data over closed channel")
        } catch {}
        
        try await answerer.disconnectChannel(id: dcID, peerConnectionID: pcID)
        do {
            try await answererToInitiatorChannel.send(data: Data("This message should never reach initiator.".utf8))
            XCTFail("Expected to fail when trying to send data over closed channel")
        } catch {}
    }
}

extension SignalingClient {

    static func passthrough() -> (caller: Self, answerer: Self) {
        let (toCallerAsyncStream, fromCallerAsyncContinuation) = AsyncStream.streamWithContinuation(Data.self)
        let (toAnswererAsyncStream, fromAnswererAsyncContinuation) = AsyncStream.streamWithContinuation(Data.self)
        let caller = Self.passthrough(stream: toCallerAsyncStream, continuation: fromAnswererAsyncContinuation)
        let answerer = Self.passthrough(stream: toAnswererAsyncStream, continuation: fromCallerAsyncContinuation)
        return (caller, answerer)
    }
}
