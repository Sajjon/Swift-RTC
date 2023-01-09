//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-09.
//

import Foundation

public enum ToWallet: Sendable, Codable, Hashable {
    case requestFromDapp(RequestFromDapp)
    case message(Message)
}

public extension ToWallet {
    enum RequestFromDapp: String, Sendable, Codable, Hashable {
        case login
    }
    
    enum Message: Sendable, Codable, Hashable {
        /// We received a message received receipt, where remote client confirms it receive a message sent by us.
        case receipt(ChunkedMessagePackage.MessageID)
    }
}
