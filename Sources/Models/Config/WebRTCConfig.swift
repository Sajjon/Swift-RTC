//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-27.
//

import Foundation

public struct WebRTCConfig: Sendable, Hashable, Codable {
    public let iceServers: [ICEServer]
    public let defineDtlsSrtpKeyAgreement: Bool
    
    public init(
        defineDtlsSrtpKeyAgreement: Bool = true,
        iceServers: [ICEServer] = [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302"
        ]
    ) {
        self.defineDtlsSrtpKeyAgreement = defineDtlsSrtpKeyAgreement
        self.iceServers = iceServers
    }
    
    public static let `default` = Self()
}

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
