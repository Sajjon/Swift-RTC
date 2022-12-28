//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-27.
//

import Foundation

public struct SignalingConfig: Sendable, Codable, Hashable {
  
    public let webSocketURL: URL

    public init(
        webSocketURL: URL
    ) {
        self.webSocketURL = webSocketURL
    }
}

public extension SignalingConfig {
    static let `default`: Self = Self(
        webSocketURL: .init(string: "wss://example.com:443")!
    )
}
