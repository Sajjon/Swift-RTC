//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-15.
//

import Foundation

public extension RadixSignalMsg {
    
    enum Incoming: Sendable, Hashable, Decodable, CustomStringConvertible {
        case fromSignalingServerItself(FromSignalingServerItself)
        case fromRemoteClientOriginally(FromRemoteClientOriginally)
    }
    
}

public extension RadixSignalMsg.Incoming {
    var description: String {
        switch self {
        case let .fromSignalingServerItself(value):
            return "fromSignalingServerItself(\(value))"
        case let .fromRemoteClientOriginally(value):
            return "fromRemoteClientOriginally(\(String(describing: value)))"
        }
    }
}

public extension RadixSignalMsg.Incoming {
    typealias RequestId = String
    typealias FromRemoteClientOriginally = RPCMessage
    enum FromSignalingServerItself: Sendable, Hashable, CustomStringConvertible {
        case notification(Notification)
        case responseForRequest(ResponseForRequest)
    }
}


public extension RadixSignalMsg.Incoming.FromSignalingServerItself {
    var description: String {
        switch self {
        case let .notification(notification):
            return "notification(\(notification))"
        case let .responseForRequest(responseForRequest):
            return "responseForRequest(\(responseForRequest))"
        }
    }
}

public extension RadixSignalMsg.Incoming.FromSignalingServerItself {
    
    var responseForRequest: ResponseForRequest? {
        switch self {
        case let .responseForRequest(responseForRequest):
            return responseForRequest
        case .notification:
            return nil
        }
    }
    
    var notification: Notification? {
        switch self {
        case let .notification(value):
            return value
        case .responseForRequest:
            return nil
        }
    }
    
}

public extension RadixSignalMsg.Incoming {
    
    var fromSignalingServerItself: FromSignalingServerItself? {
        switch self {
        case let .fromSignalingServerItself(value): return value
        case .fromRemoteClientOriginally: return nil
        }
    }
    
    
    var fromRemoteClientOriginally: RPCMessage? {
        switch self {
        case let .fromRemoteClientOriginally(value): return value
        case .fromSignalingServerItself: return nil
        }
    }
    
    
    var responseForRequest: FromSignalingServerItself.ResponseForRequest? {
        fromSignalingServerItself?.responseForRequest
    }
    
    var notification: FromSignalingServerItself.Notification? {
        fromSignalingServerItself?.notification
    }
    
    var rtcAnswerRPCMessageFromRemoteClient: RPCMessage? {
        guard
            let rpcMessage = fromRemoteClientOriginally,
            rpcMessage.method == .answer
        else {
            return nil
        }
        return rpcMessage
    }
    
    var rtcOfferRPCMessageFromRemoteClient: RPCMessage? {
        guard
            let rpcMessage = fromRemoteClientOriginally,
            rpcMessage.method == .offer
        else {
            return nil
        }
        return rpcMessage
    }
    
    var rtcICECandidateRPCMessageFromRemoteClient: RPCMessage? {
        guard
            let rpcMessage = fromRemoteClientOriginally,
            rpcMessage.method == .addICE
        else {
            return nil
        }
        return rpcMessage
    }
    

    
}
 
public extension RadixSignalMsg.Incoming {
    var isRemoteClientConnected: Bool {
        guard let notification = notification else { return false }
        return notification.isRemoteClientConnected
    }
    var remoteClientIsAlreadyConnected: Self? {
        fromSignalingServerItself?.remoteClientIsAlreadyConnected.map { .fromSignalingServerItself($0) }
    }
    var remoteClientJustConnected: Self? {
        fromSignalingServerItself?.remoteClientJustConnected.map { .fromSignalingServerItself($0) }
    }
}
public extension RadixSignalMsg.Incoming.FromSignalingServerItself {
    var isRemoteClientConnected: Bool {
        guard let notification = notification else { return false }
        return notification.isRemoteClientConnected
    }
    var isRemoteClientJustConnected: Bool {
        guard let notification = notification else { return false }
        return notification.isRemoteClientJustConnected
    }
    var isRemoteClientIsAlreadyConnected: Bool {
        guard let notification = notification else { return false }
        return notification.isRemoteClientIsAlreadyConnected
    }
    
    var remoteClientIsAlreadyConnected: Self? {
        notification?.remoteClientIsAlreadyConnected.map { .notification($0) }
    }
    var remoteClientJustConnected: Self? {
        notification?.remoteClientJustConnected.map { .notification($0) }
    }
}
