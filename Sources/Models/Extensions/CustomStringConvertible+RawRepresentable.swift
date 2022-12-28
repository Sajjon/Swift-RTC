//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

extension CustomStringConvertible where Self: RawRepresentable, RawValue == String {
    public var description: String { rawValue }
}
