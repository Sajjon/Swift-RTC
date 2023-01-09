//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-16.
//

import Foundation
import CryptoKit

public struct ConnectionSecrets: Sendable, Hashable, Codable {
    public let connectionPassword: ConnectionPassword
    public let connectionID: PeerConnectionID
    public let encryptionKey: EncryptionKey

    public init(
        connectionPassword: ConnectionPassword,
        connectionID: PeerConnectionID,
        encryptionKey: EncryptionKey
    ) {
        self.connectionPassword = connectionPassword
        self.connectionID = connectionID
        self.encryptionKey = encryptionKey
    }
}


public extension ConnectionSecrets {
    static func from(connectionPassword: ConnectionPassword) throws -> Self {
 
        let connectionID = try PeerConnectionID(password: connectionPassword)
        
        return try Self(
            connectionPassword: connectionPassword,
            connectionID: connectionID,
            encryptionKey: .init(data: connectionPassword.data.data)
        )
    }
}

public extension PeerConnectionID {
    init(password connectionPassword: ConnectionPassword) throws {
        
        let connectionIDData = Data(SHA256.hash(data: connectionPassword.data.data))
        
        try self.init(data: connectionIDData)
               
    }
}

#if DEBUG
public extension ConnectionSecrets {

    static let placeholder = Self(
        connectionPassword: .placeholder,
        connectionID: .placeholder,
        encryptionKey: try! .init(data: .deadbeef32Bytes)
    )

}
#endif // DEBUG
