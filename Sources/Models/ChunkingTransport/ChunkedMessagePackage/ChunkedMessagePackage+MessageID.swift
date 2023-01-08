//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-09.
//

import Foundation


public extension ChunkedMessagePackage {
    
    
    typealias MessageID = String
    
    var messageId: MessageID {
        switch self {
        case .chunk(let value): return value.messageId
        case .metaData(let value): return value.messageId
        case .receiveMessageConfirmation(let value): return value.messageId
        case .receiveMessageError(let value): return value.messageId
        }
    }
}
