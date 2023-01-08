//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-16.
//

import Foundation

public extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest.RequestFailure {
    struct InvalidMessageError: Swift.Error, Sendable, Hashable, CustomStringConvertible {
        public let reason: JSONValue
        public let messageSentThatWasInvalid: RPCMessage
    }
}

public extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest.RequestFailure.InvalidMessageError {
    var description: String {
        "reason: \(String(describing: reason)), requestIdOfInvalidMsg: \(messageSentThatWasInvalid.requestId)"
    }
}
