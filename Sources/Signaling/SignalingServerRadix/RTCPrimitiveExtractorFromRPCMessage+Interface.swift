//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-18.
//

import Foundation
import P2PModels

public final class RTCPrimitiveExtractorFromRPCMessage: Sendable {
    private let signalingServerEncryption: SignalingServerEncryption
    private let connectionID: PeerConnectionID
   
    public init(
        connectionID: PeerConnectionID,
        signalingServerEncryption: SignalingServerEncryption
    ) {
        self.connectionID = connectionID
        self.signalingServerEncryption = signalingServerEncryption
    }
}

public extension RTCPrimitiveExtractorFromRPCMessage {
    convenience init(
        connectionSecrets: ConnectionSecrets
    ) {
        self.init(
            connectionID: connectionSecrets.connectionID,
            signalingServerEncryption: .init(key: connectionSecrets.encryptionKey)
        )
    }
    
}

public extension RTCPrimitiveExtractorFromRPCMessage {
    struct WrongConnectionID: LocalizedError {
        public let expected: PeerConnectionID
        public let unexpected: PeerConnectionID
        public var errorDescription: String? {
            "Wrong connection ID, expected: \(expected), but got: \(unexpected)"
        }
    }
    func extract(rpcMessage: RPCMessage) throws -> RTCPrimitive {
        guard rpcMessage.connectionID == self.connectionID else {
            throw WrongConnectionID(
                expected: self.connectionID,
                unexpected: rpcMessage.connectionID
            )
        }
        let decrypted = try signalingServerEncryption.decrypt(data: rpcMessage.encryptedPayload.data)
        let primitive = try _decodeWebRTCPrimitive(method: rpcMessage.method, data: decrypted)
        return primitive
    }
}

@Sendable
public func _decodeWebRTCPrimitive(
    method: RPCMethod,
    data: Data
) throws -> RTCPrimitive {
    try _decodeWebRTCPrimitive(method: method, data: data, jsonDecoder: .init())
}

@Sendable
public func _decodeWebRTCPrimitive(
    method: RPCMethod,
    data: Data,
    jsonDecoder: JSONDecoder
) throws -> RTCPrimitive {
    switch method {
    case .offer:
        return try .offer(jsonDecoder.decode(Offer.self, from: data))
    case .answer:
        return try .answer(jsonDecoder.decode(Answer.self, from: data))
    case .addICE:
        return try .addICE(jsonDecoder.decode(ICECandidate.self, from: data))
    case .removeICEs:
        return try .removeICEs(jsonDecoder.decode([ICECandidate].self, from: data))
    }
}
