//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-09.
//

import Foundation

public enum ChunkedMessagePackage: Codable, Sendable & Equatable {
    case metaData(ChunkedMessageMetaDataPackage)
    case chunk(ChunkedMessageChunkPackage)
    case receiveMessageConfirmation(ChunkedMessageReceiveConfirmation)
    case receiveMessageError(ChunkedMessageReceiveError)
}

#if DEBUG
public extension Array where Element == ChunkedMessagePackage {
    static let placeholder: Self = [
        .metaData(.placeholder(chunkCount: 2)),
        .chunk(.placeholder(index: 0)),
        .chunk(.placeholder(index: 1))
    ]
}
#endif
