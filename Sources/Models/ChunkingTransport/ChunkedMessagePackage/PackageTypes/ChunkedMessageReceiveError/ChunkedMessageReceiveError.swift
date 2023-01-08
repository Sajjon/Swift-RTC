//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-09.
//

import Foundation

public struct ChunkedMessageReceiveError: LocalizedError, Codable, Sendable, Hashable {
    public let messageId: ChunkedMessagePackage.MessageID
    public let error: Reason
    public init(messageId: ChunkedMessagePackage.MessageID, error: Reason) {
        self.messageId = messageId
        self.error = error
    }
}

public extension ChunkedMessageReceiveError {
    enum Reason: String, Sendable, Hashable, Codable {
        case messageHashesMismatch
    }
}
