//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-17.
//

import Foundation
import CryptoKit

public struct SignalingServerEncryption: Sendable {
    private let key: EncryptionKey
    public init(key: EncryptionKey) {
        self.key = key
    }
}

public extension SignalingServerEncryption {
    func encrypt(_ message: RPCMessageUnencrypted) throws -> RPCMessage {
        let encrypted = try AES.GCM
            .seal(
                message.unencryptedPayload,
                using: key.symmetric
            )
            .combined!
        
        return RPCMessage(
            encryption: encrypted,
            of: message
        )
    }
    func decrypt(data msg: Data) throws -> Data {
        try AES.GCM.open(
            AES.GCM.SealedBox(combined: msg),
            using: key.symmetric
        )
    }
}

