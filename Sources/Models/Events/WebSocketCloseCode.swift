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
