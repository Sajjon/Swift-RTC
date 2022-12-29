//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-29.
//

import Foundation

public protocol Disconnecting: Sendable, Hashable, Identifiable {
    func disconnect() async
}
