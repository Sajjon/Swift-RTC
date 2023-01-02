//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public enum DataChannelState: String, Sendable, Hashable, CustomStringConvertible {
    case open, connecting, closed, closing
}
