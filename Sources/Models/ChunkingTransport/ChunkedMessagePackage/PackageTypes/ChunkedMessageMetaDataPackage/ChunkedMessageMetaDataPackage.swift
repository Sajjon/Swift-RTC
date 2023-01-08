//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-09.
//

import Foundation
import Bite

public struct ChunkedMessageMetaDataPackage: Codable, Sendable & Equatable {
    
    public let messageId: ChunkedMessagePackage.MessageID
    public let chunkCount: Int
    public let messageByteCount: Int
    public let hashOfMessage: HexCodable
    
    public init(
        messageID: ChunkedMessagePackage.MessageID,
        chunkCount: Int,
        messageByteCount: Int,
        hashOfMessage: HexCodable
    ) {
        self.messageId = messageID
        self.chunkCount = chunkCount
        self.messageByteCount = messageByteCount
        self.hashOfMessage = hashOfMessage
    }
}

#if DEBUG
public extension ChunkedMessageMetaDataPackage {
    static func placeholder(chunkCount: Int) -> Self {
        .init(
            messageID: .deadbeef32Bytes,
            chunkCount: chunkCount,
            messageByteCount: 1337,
            hashOfMessage: .deadbeef32Bytes
        )
    }
}
#endif