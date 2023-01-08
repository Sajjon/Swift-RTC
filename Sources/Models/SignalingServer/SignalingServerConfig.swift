//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-13.
//

import Foundation

public struct SignalingServerConfig: Sendable, Hashable, Codable {
    
    private let signalingServerBaseURL: URL
    public let websocketPingInterval: TimeInterval?
    
    public init(
        websocketPingInterval: TimeInterval? = 55,
        signalingServerBaseURL: URL = .defaultBaseForSignalingServer
    ) {
        self.signalingServerBaseURL = signalingServerBaseURL
        self.websocketPingInterval = websocketPingInterval
    }
    
    public static let `default` = Self()
}

public extension URL {
    static let defaultBaseForSignalingServer = Self(string: "wss://signaling-server-betanet.radixdlt.com")!
}


public extension SignalingServerConfig {
    
    func signalingServerURL(
        connectionID: PeerConnectionID,
        source: ClientSource = .mobileWallet
    ) throws -> URL {
        let target: ClientSource = source == .mobileWallet ? .browserExtension : .mobileWallet
        
        let url = signalingServerBaseURL.appendingPathComponent(
            connectionID.hex()
        )
       
        guard
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw FailedToCreateURL()
        }
        
        urlComponents.queryItems = [
            .init(
                name: QueryParameterName.target.rawValue,
                value: target.rawValue
            ),
            .init(
                name: QueryParameterName.source.rawValue,
                value: source.rawValue
            ),
        ]
        
        guard let serverURL = urlComponents.url else {
            throw FailedToCreateURL()
        }
        
        return serverURL
    }
}


public struct FailedToCreateURL: LocalizedError {
    public var errorDescription: String? {
        "Failed to create url"
    }
}

public enum ClientSource: String, Codable, Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    case browserExtension = "extension"
    case mobileWallet = "wallet"
}

public extension ClientSource {
    var debugDescription: String {
        rawValue
    }
    var description: String {
        switch self {
        case .browserExtension: return "Browser Extension"
        case .mobileWallet: return "Mobile Wallet"
        }
    }
}


private extension SignalingServerConfig {
    enum QueryParameterName: String {
        case target, source
    }
}


#if DEBUG
public extension SignalingServerConfig {
    static let placeholder = Self.default
}
#endif // DEBUG
