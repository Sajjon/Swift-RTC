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
    
    public var sendToRemote: SendToRemoteFunctionType
    public var rtcPrimitivesFromRemoteAsyncSequence: ReceiveFromRemoteAsyncSequence
    public var sessionInitiationProtocolEventsAsyncSequence: SessionInitiationProtocolEventsAsyncSequence?
    public var shutdown: Shutdown
   
    public init(
        shutdown: @escaping Shutdown,
        sendToRemote: SendToRemoteFunctionType,
        rtcPrimitivesFromRemoteAsyncSequence: @escaping ReceiveFromRemoteAsyncSequence,
        sessionInitiationProtocolEventsAsyncSequence: SessionInitiationProtocolEventsAsyncSequence?
    ) {
        self.shutdown = shutdown
        self.sendToRemote = sendToRemote
        self.rtcPrimitivesFromRemoteAsyncSequence = rtcPrimitivesFromRemoteAsyncSequence
        self.sessionInitiationProtocolEventsAsyncSequence = sessionInitiationProtocolEventsAsyncSequence
    }
}

public extension SignalingClient {
    typealias Shutdown = @Sendable () async throws -> Void
    
    struct SendToRemoteFunctionType: Sendable {
        // Only reason we return outgoing message is for tests
        public typealias SendAction = @Sendable (RTCPrimitive) async throws -> Data

        private let sendAction: SendAction

        public init(_ sendAction: @escaping SendAction) {
            self.sendAction = sendAction
        }

        @discardableResult
        public func callAsFunction(primitive: RTCPrimitive) async throws -> Data {
            try await sendAction(primitive)
        }
    }
    
    typealias ReceiveFromRemoteAsyncSequence = @Sendable () async -> AnyAsyncSequence<RTCPrimitive>
    typealias SessionInitiationProtocolEventsAsyncSequence = @Sendable () async -> AnyAsyncSequence<SessionInitiationProtocolEvent>
}
