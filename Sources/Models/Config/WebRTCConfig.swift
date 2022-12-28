//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-27.
//

import Foundation

public struct WebRTCConfig: Sendable, Hashable, Codable {
    public let isInitator: Bool
    public let iceServers: [String]
    public init(
        isInitator: Bool,
        iceServers: [String] = ["stun:stun.l.google.com:19302",
                                        "stun:stun1.l.google.com:19302",
                                        "stun:stun2.l.google.com:19302",
                                        "stun:stun3.l.google.com:19302",
                                        "stun:stun4.l.google.com:19302"]
    ) {
        self.isInitator = isInitator
        self.iceServers = iceServers
    }
}
