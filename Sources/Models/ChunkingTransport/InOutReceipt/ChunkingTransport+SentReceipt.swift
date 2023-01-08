//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-15.
//

import Foundation

public struct ChunkingTransportSentReceipt: Sendable, Hashable, CustomStringConvertible {
    
    public let messageSent: ChunkingTransportOutgoingMessage
    public let confirmedReceivedAt: Date
    
    public init(
        messageSent: ChunkingTransportOutgoingMessage,
        confirmedReceivedAt: Date = .init()
    ) {
        self.messageSent = messageSent
        self.confirmedReceivedAt = confirmedReceivedAt
    }
}


public extension ChunkingTransportSentReceipt {
    var description: String {
        """
        confirmedReceivedAt: \(confirmedReceivedAt),
        messageSent: \(messageSent)
        """
    }
}
