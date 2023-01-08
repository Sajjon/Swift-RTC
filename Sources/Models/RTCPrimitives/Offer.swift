//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public struct Offer: Sendable, Hashable, Codable {
    public let sdp: String
    public init(sdp: String) {
        self.sdp = sdp
    }
}

