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
@testable import SignalingServerRadixTestSupport
import XCTest

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
        let _ = (try await initiatorConnectedToAnswerer.value, try await answererConnectedToInitiator.value)
        
        Task {
            for try await msg in await initiatorToAnswererChannel.incomingMessages().prefix(1) {
                XCTAssertEqual(msg, Data("Hey Initiator".utf8), "Got unexpected: '\(String(data: msg, encoding: .utf8)!)'")
                initiatorReceivedMsgExp.fulfill()
            }
        }
        
        Task {
            for try await msg in await answererToInitiatorChannel.incomingMessages().prefix(1) {
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

extension SignalingClient.Transport {
    
    static func emulatingServerBetween() -> (caller: Self, answerer: Self) {
        
        let fromCallerSubject = AsyncPassthroughSubject<Data>()
        let fromAnswererSubject = AsyncPassthroughSubject<Data>()
        
        @Sendable func transform(outgoing data: Data) throws -> Data {
            let jsonDecoder = JSONDecoder()
            let jsonEncoder = JSONEncoder()
            let rpc = try jsonDecoder.decode(RPCMessage.self, from: data)
            let incoming = RadixSignalMsg.Incoming.fromRemoteClientOriginally(rpc)
            let transformed = try jsonEncoder.encode(incoming)
//            print("🌸 transformed from:\n\n\(data.printFormatedJSON())\nto:\n\n\(transformed.printFormatedJSON())\n")
            return transformed
        }
        
        let caller: SignalingClient.Transport = .multicastPassthrough(
            incoming: fromAnswererSubject.eraseToAnyAsyncSequence(),
            send: {
                let transformed = try transform(outgoing: $0)
                fromCallerSubject.send(transformed)
            }
        )
        let answerer: SignalingClient.Transport = .multicastPassthrough(
            incoming: fromCallerSubject.eraseToAnyAsyncSequence(),
            send: {
                let transformed = try transform(outgoing: $0)
                fromAnswererSubject.send(transformed)
            }
        )
        return (caller, answerer)
        
    }
}
extension SignalingClient {
    static func passthrough(
        connectionID: PeerConnectionID = .placeholder,
        jsonEncoder: JSONEncoder = .init(),
        jsonDecoder: JSONDecoder = .init(),
        callerSource: ClientSource = .mobileWallet,
        answererSource: ClientSource = .browserExtension,
        requestId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) -> (caller: Self, answerer: Self) {
        
        let (callerTransport, answererTransport) = Transport.emulatingServerBetween()

        let caller = Self.passthrough(
            transport: callerTransport,
            connectionID: connectionID,
            jsonEncoder: jsonEncoder,
            source: callerSource,
            requestId: requestId
        )
        
        let answerer = Self.passthrough(
            transport: answererTransport,
            connectionID: connectionID,
            jsonEncoder: jsonEncoder,
            source: answererSource,
            requestId: requestId
        )
        
        return (
            caller: caller,
            answerer: answerer
        )
        
    }
}
