//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import RTCModels

public struct SignalingClient: Sendable {
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
    typealias SendToRemote = @Sendable (RTCPrimitive) async throws -> Void
    
    typealias ReceiveFromRemoteAsyncSequence = @Sendable () -> AsyncStream<RTCPrimitive>
  
}

