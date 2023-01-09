//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public struct DataChannelConfig: Sendable, Hashable, Codable {
    public let isOrdered: Bool
    public let isNegotiated: Bool
    public init(isOrdered: Bool, isNegotiated: Bool) {
        self.isNegotiated = isNegotiated
        self.isOrdered = isOrdered
    }
}

public extension DataChannelConfig {
    static let `default`: Self = .init(isOrdered: true, isNegotiated: true)
}
