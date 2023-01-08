//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-16.
//

import Foundation

public extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest {
    enum RequestFailure: Sendable, Hashable, LocalizedError, CustomStringConvertible {
        case noRemoteClientToTalkTo(RadixSignalMsg.Incoming.RequestId)
        case validationError(ValidationError)
        case invalidMessageError(InvalidMessageError)
    }
}

public extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest.RequestFailure {
    var errorDescription: String { self.description }
    var description: String {
        switch self {
        case let .invalidMessageError(error):
            return "invalidMessageError(\(error))"
        case let .validationError(error):
            return "validationError(\(error))"
        case let .noRemoteClientToTalkTo(requestId):
            return "noRemoteClientToTalkTo(requestId: \(requestId))"
        }
    }
}

internal extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest.RequestFailure {
    var invalidMessageError: InvalidMessageError? {
        switch self {
        case let .invalidMessageError(value): return value
        case .noRemoteClientToTalkTo, .validationError: return nil
        }
    }
    
    var validationError: ValidationError? {
        switch self {
        case let .validationError(value): return value
        case .noRemoteClientToTalkTo, .invalidMessageError:
            return nil
            
        }
    }
}
