//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-08.
//

import Foundation
@testable import SignalingServerRadix
import Tunnel
import XCTest
import SignalingServerClient
import WebSocket
import P2PModels
import CryptoKit // for randomness

final class WebSocketTests: XCTestCase {
  
    func test_establish_connection() async throws {

        let connectionID: PeerConnectionID = try {
            let random32Bytes: Data = SymmetricKey(size: .bits256).withUnsafeBytes({ Data($0) })
            let connectionPassword = try ConnectionPassword(data: random32Bytes)
            let connectionSecrets = try ConnectionSecrets.from(connectionPassword: connectionPassword)
            return connectionSecrets.connectionID
        }()
        
        let websocketMobile = try SignalingClient.Transport.webSocket(
            peerConnectionID: connectionID,
            url: SignalingServerConfig.default.signalingServerURL(
                connectionID: connectionID,
                source: .mobileWallet
            )
        )
        let websocketBrowser = try SignalingClient.Transport.webSocket(
            peerConnectionID: connectionID,
            url: SignalingServerConfig.default.signalingServerURL(
                connectionID: connectionID,
                source: .browserExtension
            )
        )
        
        let connectionEstablished = expectation(description: "Clients can establish a websocket connection")
        connectionEstablished.expectedFulfillmentCount = 2

        Task {
            for try await mobileConnectionState in try await websocketMobile.readyStateUpdates() {
                if mobileConnectionState == .connected {
                    connectionEstablished.fulfill()
                }
            }
        }

        Task {
            for try await browserConnectionState in try await websocketBrowser.readyStateUpdates() {
                if browserConnectionState == .connected {
                    connectionEstablished.fulfill()
                }
            }
        }

        wait(for: [connectionEstablished], timeout: 3)
    }
}
