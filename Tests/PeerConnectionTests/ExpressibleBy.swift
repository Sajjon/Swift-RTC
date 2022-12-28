//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation
import RTCModels

extension PeerConnectionID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self.init(id: value)
    }
}

extension DataChannelID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int32) {
        self.init(id: value)
    }
}
