//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public struct DataChannelID: Sendable, Hashable {
    public let label: String
    public let id: Int32
    public init(id: Int32, label: String) {
        self.id = id
        self.label = "\(id)"
    }
    public init(id: Int32) {
        self.init(id: id, label: "\(id)")
    }
    public init(label: String) {
        self.init(id: Int32(label)!, label: label)
    }
}

#if DEBUG
extension DataChannelID: ExpressibleByIntegerLiteral {
    public init(integerLiteral id: Int32) {
        self.init(id: id)
    }
}
#endif
