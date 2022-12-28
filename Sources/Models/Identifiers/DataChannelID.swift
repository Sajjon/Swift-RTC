//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation


public struct DataChannelID: Hashable {
    public let id: Int32
    public init(id: Int32) {
        self.id = id
    }
}
