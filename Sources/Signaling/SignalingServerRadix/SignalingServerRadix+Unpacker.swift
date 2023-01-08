//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-08.
//

import Foundation
import SignalingServerClient
import P2PModels

// MARK: Unpacker
public extension SignalingClient {
    struct Unpacker: Sendable {
        public typealias Unpack = @Sendable (RPCMessage) throws -> RTCPrimitive
        public var unpack: Unpack
        public init(unpack: @escaping Unpack) {
            self.unpack = unpack
        }
    }
}

public extension SignalingClient.Unpacker {
    
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
        signalingServerEncryption: SignalingServerEncryption
    ) -> Self {
        Self.init(unpack: { (rpcMessage: RPCMessage) throws -> RTCPrimitive in
            
            struct WrongConnectionID: LocalizedError {
                public let expected: PeerConnectionID
                public let unexpected: PeerConnectionID
                public var errorDescription: String? {
                    "Wrong connection ID, expected: \(expected), but got: \(unexpected)"
                }
            }
            
            guard rpcMessage.connectionID == connectionID else {
                throw WrongConnectionID(
                    expected: connectionID,
                    unexpected: rpcMessage.connectionID
                )
            }
            
            let decrypted = try signalingServerEncryption.decrypt(
                data: rpcMessage.encryptedPayload.data
            )
            
            return try RTCPrimitive.decode(
                method: rpcMessage.method,
                data: decrypted
            )
        })
    }
}

// MARK: TestSupport
#if DEBUG
public extension SignalingClient.Unpacker {
    /// An unpacker which assumes that the `encryptedPayload` of the RPCMessage is in fact NOT
    /// encrypted and tried to JSON decode it into an RTCPrimitive.
    static var jsonDecodeOnly: Self {
        .init(unpack: { (rpcMessage: RPCMessage) throws -> RTCPrimitive in
            try .decode(
                method: rpcMessage.method,
                // Assumes that the `encryptedPayload` is infact NOT encrypted.
                data: rpcMessage.encryptedPayload.data
            ) })
    }
}
#endif
