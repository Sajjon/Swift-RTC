//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-18.
//

import Foundation
import P2PModels

public final class RTCPrimitiveToMessagePacker: Sendable {
    private let jsonEncoder: JSONEncoder
    private let signalingServerEncryption: SignalingServerEncryption
    private let connectionID: PeerConnectionID
    public init(
        connectionID: PeerConnectionID,
        signalingServerEncryption: SignalingServerEncryption,
        jsonEncoder: JSONEncoder = .init()
    ) {
        self.connectionID = connectionID
        self.signalingServerEncryption = signalingServerEncryption
        self.jsonEncoder = jsonEncoder
    }
}
public extension RTCPrimitiveToMessagePacker {
    convenience init(
        connectionSecrets: ConnectionSecrets,
        jsonEncoder: JSONEncoder = .init()
    ) {
        self.init(
            connectionID: connectionSecrets.connectionID,
            signalingServerEncryption: .init(key: connectionSecrets.encryptionKey),
            jsonEncoder: jsonEncoder
        )
    }

}

public extension RTCPrimitiveToMessagePacker {
    
    func pack(primitive: RTCPrimitive) throws -> RadixSignalMsg.Outgoing {

        let unencryptedPayload = try jsonEncoder.encode(primitive)
        
        let unencryptedMessage = RPCMessageUnencrypted(
            method: primitive.method,
            source: .mobileWallet,
            connectionId: connectionID,
            requestId: .init(),
            unencryptedPayload: unencryptedPayload
        )
        
        return try signalingServerEncryption.encrypt(unencryptedMessage)
    }
}


internal extension RTCPrimitive {
    var method: RPCMethod {
        switch self {
        case .answer: return .answer
        case .addICE: return .addICE
        case .removeICEs: return .removeICEs
        case .offer: return .offer
        }
    }
}

