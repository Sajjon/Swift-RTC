//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-30.
//

import Foundation
import XCTest
@testable import P2PClient
@testable import Tunnel

extension RTCClient {
    
    /// Throws an error if no `PeerConnection` matching the `peerConnectionID`
    /// exists.
    func newDataTunnel(
        peerConnectionID: PeerConnectionID,
        channelID: DataChannelID,
        config: DataChannelConfig
    ) async throws -> Tunnel<DataChannelID, DataChannelState, Data, Data> {
        try await newTunnel(
            peerConnectionID: peerConnectionID,
            channelID: channelID,
            config: config,
            encoder: .passthrough,
            decoder: .passthrough
        )
    }
}

final class TunnelTests: XCTestCase {
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
        
        let initiatorToAnswererTunnel = try await initiator.newDataTunnel(
            peerConnectionID: pcID,
            channelID: dcID,
            config: dcConfig
        )
        let answererToInitiatorTunnel = try await answerer.newDataTunnel(
            peerConnectionID: pcID,
            channelID: dcID,
            config: dcConfig
        )
        
        let initiatorConnectedToAnswerer = Task {
            let _ = try await initiatorToAnswererTunnel.readyStateUpdates().first(where: { $0 == .open })
        }
        
        let answererConnectedToInitiator = Task {
            let _ = try await answererToInitiatorTunnel.readyStateUpdates().first(where: { $0 == .open })
        }
        let _ = (try await initiatorConnectedToAnswerer.value, try await answererConnectedToInitiator.value)
        
        Task {
            for try await msg in await initiatorToAnswererTunnel.incomingMessages().prefix(1) {
                XCTAssertEqual(msg, Data("Hey Initiator".utf8), "Got unexpected: '\(String(data: msg, encoding: .utf8)!)'")
                initiatorReceivedMsgExp.fulfill()
            }
        }
        
        Task {
            for try await msg in await answererToInitiatorTunnel.incomingMessages().prefix(1) {
                XCTAssertEqual(msg, Data("Hey Answerer".utf8), "Got unexpected: '\(String(data: msg, encoding: .utf8)!)'")
                answererReceivedMsgExp.fulfill()
            }
        }
        
        Task {
            try await initiatorToAnswererTunnel.send(Data("Hey Answerer".utf8))
        }
        
        Task {
            try await answererToInitiatorTunnel.send(Data("Hey Initiator".utf8))
        }
        
        await waitForExpectations(timeout: 3)
    }
}
