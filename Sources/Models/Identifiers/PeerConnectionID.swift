//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public struct PeerConnectionID: Hashable {
    public let id: Int64
    public init(id: Int64) {
        self.id = id
    }
    public static func random() -> Self {
        .init(id: .random(in: 0..<Int64.max))
    }
}
