//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public enum PeerConnectionState: String, Sendable, Hashable, CustomStringConvertible {
    case closed, new, connecting, connected, disconnected, failed
}
