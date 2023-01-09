//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-09.
//

import Foundation

public struct Config: Sendable, Codable, Hashable {
    public let webRTC: WebRTCConfig
    public let dataChannel: DataChannelConfig
    public let negotiationRole: NegotiationRole
    public let connectionSecrets: ConnectionSecrets

}
