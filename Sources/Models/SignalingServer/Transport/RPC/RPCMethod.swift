//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-08-17.
//

import Foundation

public enum RPCMethod: String, Codable, Sendable, Hashable, CustomStringConvertible {
    case offer
    case answer
    case addICE
    case removeICEs
}
