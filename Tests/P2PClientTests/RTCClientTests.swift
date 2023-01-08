//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import AsyncExtensions
import Foundation
@testable import P2PClient
import P2PModels
import P2PPeerConnection
import SignalingServerClient
import SignalingServerRadix
import XCTest
import Tunnel

final class RTCClientTests: XCTestCase {
    
    func test_session() async throws {
        
        let initiatorReceivedMsgExp = expectation(description: "Initiator received msg")
        let answererReceivedMsgExp = expectation(description: "Answerer received msg")
        
        let (initiatorSignaling, answererSignaling) = SignalingClient.passthrough()
        
        let initiator = RTCClient(
            signaling: initiatorSignaling,
            source: .browserExtension
        )
        
        let answerer = RTCClient(
            signaling: answererSignaling,
            source: .mobileWallet
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
            let _ = try await initiatorToAnswererChannel.readyStateUpdates().first(where: { $0 == .open })
        }
        
        let answererConnectedToInitiator = Task {
            let _ = try await answererToInitiatorChannel.readyStateUpdates().first(where: { $0 == .open })
        }
        let _ = try await (initiatorConnectedToAnswerer.value, answererConnectedToInitiator.value)
        
        Task {
            for try await msg in try await initiatorToAnswererChannel.incomingMessages().prefix(1) {
                XCTAssertEqual(msg, Data("Hey Initiator".utf8), "Got unexpected: '\(String(data: msg, encoding: .utf8)!)'")
                initiatorReceivedMsgExp.fulfill()
            }
        }
        
        Task {
            for try await msg in try await answererToInitiatorChannel.incomingMessages().prefix(1) {
                XCTAssertEqual(msg, Data("Hey Answerer".utf8), "Got unexpected: '\(String(data: msg, encoding: .utf8)!)'")
                answererReceivedMsgExp.fulfill()
            }
        }
        
        Task {
            try await initiatorToAnswererChannel.send(Data("Hey Answerer".utf8))
        }
        
        Task {
            try await answererToInitiatorChannel.send(Data("Hey Initiator".utf8))
        }
        
        await waitForExpectations(timeout: 5)
        
        try await initiator.disconnectChannel(id: dcID, peerConnectionID: pcID)
        do {
            try await initiatorToAnswererChannel.send(Data("This message should never reach answerer.".utf8))
            XCTFail("Expected to fail when trying to send data over closed channel")
        } catch {}
        
        try await answerer.disconnectChannel(id: dcID, peerConnectionID: pcID)
        do {
            try await answererToInitiatorChannel.send(Data("This message should never reach initiator.".utf8))
            XCTFail("Expected to fail when trying to send data over closed channel")
        } catch {}
    }
}
