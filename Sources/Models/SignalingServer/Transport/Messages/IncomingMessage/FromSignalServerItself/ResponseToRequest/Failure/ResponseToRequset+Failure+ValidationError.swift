//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-16.
//

import Foundation

public extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest.RequestFailure {
    struct ValidationError: Swift.Error, Sendable, Hashable, CustomStringConvertible {
        public let reason: JSONValue
        public let requestId: RadixSignalMsg.Incoming.RequestId
    }
}

public extension RadixSignalMsg.Incoming.FromSignalingServerItself.ResponseForRequest.RequestFailure.ValidationError {
    var description: String {
        "reason: \(String(describing: reason)), requestId: \(requestId)"
    }
}
