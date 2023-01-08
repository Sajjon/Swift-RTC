//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-02.
//

import Foundation

public enum WebSocketCloseCode: String, Sendable, Hashable, Codable, CustomStringConvertible {
    case abnormalClosure, invalid, normalClosure, goingAway, protocolError, unsupportedData, noStatusReceived, invalidFramePayloadData, policyViolation, messageTooBig, mandatoryExtensionMissing, internalServerError, tlsHandshakeFailure
}

public extension URLSessionWebSocketTask.CloseCode {
    func swiftify() -> WebSocketCloseCode {
        switch self {
        case .abnormalClosure:
            return .abnormalClosure
        case .invalid:
            return .invalid
        case .normalClosure:
            return .normalClosure
        case .goingAway:
            return .goingAway
        case .protocolError:
            return .protocolError
        case .unsupportedData:
            return .unsupportedData
        case .noStatusReceived:
            return .noStatusReceived
        case .invalidFramePayloadData:
            return .invalidFramePayloadData
        case .policyViolation:
            return .policyViolation
        case .messageTooBig:
            return .messageTooBig
        case .mandatoryExtensionMissing:
            return .mandatoryExtensionMissing
        case .internalServerError:
            return .internalServerError
        case .tlsHandshakeFailure:
            return .tlsHandshakeFailure
        @unknown default:
            fatalError("unknown unsupported WebSocketCloseCode: \(String(describing: self))")
        }
    }
}
