//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-09.
//

import Foundation

public extension ChunkedMessagePackage {
    
    enum CodingKeys: String, CodingKey {
        case packageType
    }
    
    init(from decoder: Decoder) throws {
        let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
        let container = try decoder.singleValueContainer()
        let packageType = try keyedContainer.decode(PackageType.self, forKey: .packageType)
        switch packageType {
        case .metaData:
            self = try .metaData(
                container.decode(ChunkedMessageMetaDataPackage.self)
            )
        case .chunk:
            self = try .chunk(
                container.decode(ChunkedMessageChunkPackage.self)
            )
        case .receiveMessageConfirmation:
            self = try .receiveMessageConfirmation(
                container.decode(ChunkedMessageReceiveConfirmation.self)
            )
        case .receiveMessageError:
            self = try .receiveMessageError(
                container.decode(ChunkedMessageReceiveError.self)
            )
        }
    }
    
 

}