//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-06.
//

import Foundation
import AsyncExtensions

extension AnyAsyncIterator: @unchecked Sendable where Self.Element: Sendable {}
extension AnyAsyncSequence: @unchecked Sendable where Self.AsyncIterator: Sendable {}
