//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-08.
//

import Foundation
import SignalingServerClient
import P2PModels

// MARK: Packer
public extension SignalingClient {
    struct Packer: Sendable {
        public typealias Pack = @Sendable (RTCPrimitive) throws -> RPCMessage
        public var pack: Pack
        public init(pack: @escaping Pack) {
            self.pack = pack
        }
    }
}

public extension SignalingClient.Packer {
    
    static func radix(
        connectionSecrets: ConnectionSecrets
    ) -> Self {
        .radix(
            connectionID: connectionSecrets.connectionID,
            signalingServerEncryption: .init(key: connectionSecrets.encryptionKey)
        )
    }
    
    static func radix(
        connectionID: PeerConnectionID,
        signalingServerEncryption: SignalingServerEncryption,
        jsonEncoder: JSONEncoder = .init()
    ) -> Self {
        return Self(
            pack: { (primitive: RTCPrimitive) throws -> RPCMessage in
                let unencryptedPayload = try jsonEncoder.encode(primitive)
                
                let unencryptedMessage = RPCMessageUnencrypted(
                    method: primitive.rpcMethod,
                    source: .mobileWallet,
                    connectionId: connectionID,
                    requestId: .init(),
                    unencryptedPayload: unencryptedPayload
                )
                
                return try signalingServerEncryption.encrypt(unencryptedMessage)
            }
        )
    }
}

#if DEBUG
public extension SignalingClient.Packer {
    /// A packer which does not perform any encryption of modification otherwise of the RTCPrimitive
    /// simply puts the JSON encoding of the RTCPrimitive as "encryptedData" (it is not encrypted) in
    /// the RPCMessage.
    static func jsonEncodeOnly(
        connectionID: PeerConnectionID = .placeholder,
        jsonEncoder: JSONEncoder = .init(),
        source: ClientSource,
        requestId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) -> Self {
        .init(pack: { (primitive: RTCPrimitive) throws -> RPCMessage in
            
            let json = try jsonEncoder.encode(primitive)
            
            let unencrypted = RPCMessageUnencrypted(
                method: primitive.rpcMethod,
                source: source,
                connectionId: connectionID,
                requestId: requestId(),
                unencryptedPayload: json
            )
            
            return RPCMessage(
                encryption: json, // performs NO encryption
                of: unencrypted
            )
        })
    }
}
#endif // DEBUG
