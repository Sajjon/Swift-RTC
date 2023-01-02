//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import AsyncExtensions
import Foundation
import RTCModels

public protocol RTCPrimitiveEventProtocol {
    var rtcPrimitive: RTCPrimitive? { get }
    init(rtcPrimitive: RTCPrimitive)
}

public protocol SIPEventProtocol {
    var sipEvent: SessionInitiationProtocolEvent? { get }
    init(sipEvent: SessionInitiationProtocolEvent)
}

public struct SignalingClient<SignalingServerMessage>: Sendable where
SignalingServerMessage: Sendable & RTCPrimitiveEventProtocol & SIPEventProtocol & Equatable & Codable
{
    public var sendToRemote: SendToRemote
    public var receiveFromRemoteAsyncSequence: ReceiveFromRemoteAsyncSequence
    public init(
        sendToRemote: @escaping SendToRemote,
        receiveFromRemoteAsyncSequence: @escaping ReceiveFromRemoteAsyncSequence
    ) {
        self.sendToRemote = sendToRemote
        self.receiveFromRemoteAsyncSequence = receiveFromRemoteAsyncSequence
    }
}

public extension SignalingClient {
    typealias SendToRemote = @Sendable (SignalingServerMessage) async throws -> Void
    typealias ReceiveFromRemoteAsyncSequence = @Sendable () -> AnyAsyncSequence<SignalingServerMessage>
    func sendToRemote(rtcPrimitive: RTCPrimitive) async throws -> Void {
        try await sendToRemote(.init(rtcPrimitive: rtcPrimitive))
    }
}
