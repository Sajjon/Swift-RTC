//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation

/// `SIP` (Session Initiation Protocol) Event
public enum SessionInitiationProtocolEvent: String, Sendable, Hashable, Codable, CustomStringConvertible {
    case remoteClientIsAlreadyConnected
    case remoteClientJustConnected
    case remoteClientDisconnected
}
