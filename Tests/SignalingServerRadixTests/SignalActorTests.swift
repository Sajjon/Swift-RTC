//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-08.
//

import Foundation
import XCTest
import SignalingServerClient
@testable import SignalingServerRadix
import Tunnel
import P2PModels

#if DEBUG
public extension SignalingClient.Transport {
    func send(sipEvent: SessionInitiationProtocolEvent) async throws {
        let incomingFromPerspectiveOfRemotePeer: RadixSignalMsg.Incoming = .fromSignalingServerItself(.notification(sipEvent))
        let data = try JSONEncoder().encode(incomingFromPerspectiveOfRemotePeer)
        try await self.send(data)
    }
}
#endif // DEBUG


final class SignalActorTests: XCTestCase {
    
    func test_that_actor_splits_incomingMessage_async_seq_into_primitiveSeq_and_sipEventSeq() async throws {
        
        
        let (callerTransport, answererTransport) = Tunnel.emulatingServerBetween()
        
        let callerActor = SignalingClient.SignalActor(
            packer: .jsonEncodeOnly(source: .mobileWallet),
            unpacker: .jsonDecodeOnly,
            transport: callerTransport,
            requireMessageSentConfirmationFromSignalingServerWhenSending: false
        )
        
        let answererActor = SignalingClient.SignalActor(
            packer: .jsonEncodeOnly(source: .browserExtension),
            unpacker: .jsonDecodeOnly,
            transport: answererTransport,
            requireMessageSentConfirmationFromSignalingServerWhenSending: false
        )
        
        
        let callSIP: Task<SessionInitiationProtocolEvent?, Error> = Task {
            var iter = await callerActor.sessionInitiationProtocolEventsAsyncSequence().makeAsyncIterator()
            let value = try await iter.next()
            return value
        }
        
        let ansSIP: Task<SessionInitiationProtocolEvent?, Error> = Task {
            var iter = await answererActor.sessionInitiationProtocolEventsAsyncSequence().makeAsyncIterator()
            let value = try await iter.next()
            return value
        }
        
        let callPrimitive: Task<RTCPrimitive?, Error> = Task {
            var iter = await callerActor.rtcPrimitivesFromRemoteAsyncSequence().makeAsyncIterator()
            let value = try await iter.next()
            return value
        }
        
        let ansPrimitive: Task<RTCPrimitive?, Error> = Task {
            var iter = await answererActor.rtcPrimitivesFromRemoteAsyncSequence().makeAsyncIterator()
            let value = try await iter.next()
            return value
        }
        
        try await answererTransport.send(sipEvent: .remoteClientIsAlreadyConnected)
        try await callerTransport.send(sipEvent: .remoteClientJustConnected)
        
        let mockOffer = Offer(sdp: "mock offer")
        let mockAnswer = Answer(sdp: "mock answer")
        try await callerActor.sendToRemote(rtcPrimitive: .offer(mockOffer))
        try await answererActor.sendToRemote(rtcPrimitive: .answer(mockAnswer))
        
        let (collectedFromCallSIP, collectedFromAnsSIP) = try await (callSIP.value, ansSIP.value)
        XCTAssertEqual(collectedFromCallSIP, .remoteClientIsAlreadyConnected)
        XCTAssertEqual(collectedFromAnsSIP, .remoteClientJustConnected)
        
        let (collectedByCallPrim, collectedByAnsPrim) = try await (callPrimitive.value, ansPrimitive.value)
        XCTAssertEqual(collectedByCallPrim, .answer(mockAnswer))
        XCTAssertEqual(collectedByAnsPrim, .offer(mockOffer))
    }
}
