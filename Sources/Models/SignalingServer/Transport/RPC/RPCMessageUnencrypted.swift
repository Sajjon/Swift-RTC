//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-17.
//

import Foundation

public struct RPCMessageUnencrypted: Sendable, Hashable {
    public let requestId: String
    public let connectionId: PeerConnectionID
    public let method: RPCMethod
    public let source: ClientSource
    public let unencryptedPayload: Data
    
    public init(
        method: RPCMethod,
        source: ClientSource,
        connectionId: PeerConnectionID,
        requestId: String,
        unencryptedPayload: Data
    ) {
        self.method = method
        self.source = source
        self.connectionId = connectionId
        self.requestId = requestId
        
        self.unencryptedPayload = unencryptedPayload
    }
}

#if DEBUG
public extension PeerConnectionID {
    static let deadbeef32Bytes: Self = try! .init(data: .deadbeef32Bytes)
}

public extension RPCMessageUnencrypted {
    
    static func placeholder(
        method: RPCMethod = .answer,
        source: ClientSource = .mobileWallet,
        connectionId: PeerConnectionID = .deadbeef32Bytes,
        requestId: String = .deadbeef32Bytes,
        unencryptedPayload: Data = .deadbeef32Bytes
    ) -> Self {
        .init(
            method: method,
            source: source,
            connectionId: connectionId,
            requestId: requestId,
            unencryptedPayload: unencryptedPayload
        )
    }
    
    static let placeholder = Self.placeholder()
}
#endif // DEBUG
