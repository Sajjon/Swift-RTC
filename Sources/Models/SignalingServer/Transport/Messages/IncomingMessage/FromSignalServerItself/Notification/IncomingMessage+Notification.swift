//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-16.
//

import Foundation

public extension RadixSignalMsg.Incoming.FromSignalingServerItself {
    typealias Notification = SessionInitiationProtocolEvent
}

internal extension RadixSignalMsg.Incoming.FromSignalingServerItself.Notification {
    var isRemoteClientConnected: Bool {
        switch self {
        case .remoteClientDisconnected: return false
        case .remoteClientIsAlreadyConnected, .remoteClientJustConnected: return true
        }
    }
    
    var isRemoteClientJustConnected: Bool {
        switch self {
        case .remoteClientDisconnected, .remoteClientIsAlreadyConnected: return false
        case .remoteClientJustConnected: return true
        }
    }
    var isRemoteClientIsAlreadyConnected: Bool {
        switch self {
        case .remoteClientJustConnected, .remoteClientDisconnected: return false
        case .remoteClientIsAlreadyConnected: return true
        }
    }
    
    var remoteClientIsAlreadyConnected: Self? {
        guard case .remoteClientIsAlreadyConnected = self else {
            return nil
        }
        return self
    }
    var remoteClientJustConnected: Self? {
        guard case .remoteClientJustConnected = self else {
            return nil
        }
        return self
    }
}

public extension RadixSignalMsg.Incoming.FromSignalingServerItself.Notification {
    var description: String {
        rawValue
    }
}

