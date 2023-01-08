//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-09.
//

import Foundation

public extension ChunkedMessagePackage {
    
    enum PackageType: String, Codable {
        case metaData
        case chunk
        case receiveMessageConfirmation
        case receiveMessageError
    }
    
    var packageType: PackageType {
        switch self {
        case .metaData: return .metaData
        case .chunk: return .chunk
        case .receiveMessageConfirmation: return .receiveMessageConfirmation
        case .receiveMessageError: return .receiveMessageError
        }
    }
}
