//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import AsyncExtensions
import Foundation
import P2PModels

public struct SignalingClient: Sendable {
    
    public var sendRTCPrimitiveToRemote: SendToRemote
    public var rtcPrimitivesFromRemoteAsyncSequence: ReceiveFromRemoteAsyncSequence
    public var sessionInitiationProtocolEventsAsyncSequence: SessionInitiationProtocolEventsAsyncSequence?
    public var shutdown: Shutdown
   
    public init(
        shutdown: @escaping Shutdown,
        sendRTCPrimitiveToRemote: @escaping SendToRemote,
        rtcPrimitivesFromRemoteAsyncSequence: @escaping ReceiveFromRemoteAsyncSequence,
        sessionInitiationProtocolEventsAsyncSequence: SessionInitiationProtocolEventsAsyncSequence?
    ) {
        self.shutdown = shutdown
        self.sendRTCPrimitiveToRemote = sendRTCPrimitiveToRemote
        self.rtcPrimitivesFromRemoteAsyncSequence = rtcPrimitivesFromRemoteAsyncSequence
        self.sessionInitiationProtocolEventsAsyncSequence = sessionInitiationProtocolEventsAsyncSequence
    }
}

public extension SignalingClient {
    typealias Shutdown = @Sendable () async throws -> Void
    
    // Only reason we return outgoing message is for tests
    typealias SendToRemote = @Sendable (RTCPrimitive) async throws -> Data
    
    typealias ReceiveFromRemoteAsyncSequence = @Sendable () async -> AnyAsyncSequence<RTCPrimitive>
    typealias SessionInitiationProtocolEventsAsyncSequence = @Sendable () async -> AnyAsyncSequence<SessionInitiationProtocolEvent>
}
