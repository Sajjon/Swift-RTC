//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public enum ICEConnectionState: String, Sendable, Hashable, CustomStringConvertible {
    case new
    case checking
    case connected
    case completed
    case failed
    case disconnected
    case closed
}
