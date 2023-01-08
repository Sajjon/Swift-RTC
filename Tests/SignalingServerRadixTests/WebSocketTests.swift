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

extension SessionInitiationProtocolEvent {
    static func from(_ data: Data) throws -> Self? {
        let jsonDecoder = JSONDecoder()
        let incoming = try jsonDecoder.decode(RadixSignalMsg.Incoming.self, from: data)
        return incoming.notification
    }
}

final class WebSocketTests: XCTestCase {
  
    func test_establish_connection() async throws {

        let connectionID: PeerConnectionID = try {
            let random32Bytes: Data = SymmetricKey(size: .bits256).withUnsafeBytes({ Data($0) })
            let connectionPassword = try ConnectionPassword(data: random32Bytes)
            let connectionSecrets = try ConnectionSecrets.from(connectionPassword: connectionPassword)
            return connectionSecrets.connectionID
        }()
        print("🎉 connectionID: \(connectionID)")
        
        let mobileIsConnected = expectation(description: "mobile client is connected")
        let browserIsConnected = expectation(description: "browser client is connected")
        let mobileNotifiedBrowserConnected = expectation(description: "mobile notified browser connected")
        let browserNotifiedMobileConnected = expectation(description: "browser notified mobile connected")
        
      
        
        let websocketBrowser = try SignalingClient.Transport.webSocket(
            peerConnectionID: connectionID,
            clientSource: .browserExtension,
            url: SignalingServerConfig.default.signalingServerURL(
                connectionID: connectionID,
                source: .browserExtension
            )
        )
        
        let websocketMobile = try SignalingClient.Transport.webSocket(
            peerConnectionID: connectionID,
            clientSource: .mobileWallet,
            url: SignalingServerConfig.default.signalingServerURL(
                connectionID: connectionID,
                source: .mobileWallet
            )
        )
  
        
        Task {
            for try await mobileSIPEvent in try await websocketMobile
                .incomingMessages()
                .compactMap({ try SessionInitiationProtocolEvent.from($0) })
            {
                print("🔮 mobileSIPEvent: \(mobileSIPEvent)")
                switch mobileSIPEvent {
                case .remoteClientIsAlreadyConnected, .remoteClientJustConnected:
                    mobileNotifiedBrowserConnected.fulfill()
                case .remoteClientDisconnected: continue
                }
            }
        }
        
        Task {
            for try await browserSIPEvent in try await websocketBrowser
                .incomingMessages()
                .compactMap({ try SessionInitiationProtocolEvent.from($0) })
            {
                print("🔮 browserSIPEvent: \(browserSIPEvent)")
                switch browserSIPEvent {
                case .remoteClientIsAlreadyConnected, .remoteClientJustConnected:
                    browserNotifiedMobileConnected.fulfill()
                case .remoteClientDisconnected: continue
                }
            }
        }
     
        
        Task {
            for try await mobileConnectionState in try await websocketMobile.readyStateUpdates() {
                if mobileConnectionState == .connected {
                    mobileIsConnected.fulfill()
                }
            }
        }
        
        Task {
            for try await browserConnectionState in try await websocketBrowser.readyStateUpdates() {
                if browserConnectionState == .connected {
                    browserIsConnected.fulfill()
                }
            }
        }
   

        await waitForExpectations(timeout: 5)
    }
}
