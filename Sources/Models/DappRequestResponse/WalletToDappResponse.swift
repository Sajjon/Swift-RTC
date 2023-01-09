//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-09.
//

import Foundation

public enum FromWallet: Sendable, Codable, Hashable {
    case responseToDapp(ResponseToDapp)
    case message(Message)
}

public extension FromWallet {
    enum ResponseToDapp: String, Sendable, Codable, Hashable {
        case loginResponse
    }
    enum Message: Sendable, Codable, Hashable {
        /// We are sending out a message received receipt confirming
        /// that we received a message from remote client.
        case receipt(ChunkedMessagePackage.MessageID)
    }
}
