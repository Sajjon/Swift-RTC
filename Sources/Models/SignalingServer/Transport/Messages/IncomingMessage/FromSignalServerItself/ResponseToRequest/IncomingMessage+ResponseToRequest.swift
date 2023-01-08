//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-16.
//

import Foundation

public extension RadixSignalMsg.Incoming.FromSignalingServerItself {
    enum ResponseForRequest: Sendable, Hashable, CustomStringConvertible {
        case success(RadixSignalMsg.Incoming.RequestId)
        case failure(RequestFailure)
    }
}

public extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest {
    var failure: RequestFailure? {
        switch self {
        case let .failure(value): return value
        case .success: return nil
        }
    }
    
    func resultOfRequest(id needle: RadixSignalMsg.Incoming.RequestId) -> Result<Void, RequestFailure>? {
        switch self {
        case let .success(id) where id == needle:
            return .success(())
        case let .failure(.invalidMessageError(invalidMessageError)) where invalidMessageError.messageSentThatWasInvalid.requestId == needle:
            return .failure(.invalidMessageError(invalidMessageError))
        case let .failure(.noRemoteClientToTalkTo(id)) where id == needle:
            return .failure(.noRemoteClientToTalkTo(id))
        case let .failure(.validationError(validationError)) where validationError.requestId == needle:
            return .failure(.validationError(validationError))
        default: return nil
        }
    }
    
    var idOfSuccessfullRequest: RadixSignalMsg.Incoming.RequestId? {
        switch self {
        case let .success(requestID): return requestID
        case .failure: return nil
        }
    }
}


public extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest {
    var description: String {
        switch self {
        case let .failure(failure):
            return "failure(\(failure))"
        case let .success(requestId):
            return "success(requestId: \(requestId))"
        }
    }
}
