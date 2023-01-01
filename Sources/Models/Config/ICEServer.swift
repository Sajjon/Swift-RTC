//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation

public struct ICEServer: Sendable, Hashable, Codable, ExpressibleByStringLiteral {
    public let serverURL: String
    public let login: Login?
    public init(serverURL: String, login: Login?) {
        self.serverURL = serverURL
        self.login = login
    }
    public init(stringLiteral serverURL: String) {
        self.init(serverURL: serverURL, login: nil)
    }
}

public extension ICEServer {
    struct Login: Sendable, Hashable, Codable {
        public let username: String
        public let credential: String
        public init(username: String, credential: String) {
            self.username = username
            self.credential = credential
        }
    }
}
