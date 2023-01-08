//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-06.
//

import Foundation
import CryptoKit

public enum RadixHasher {
    public static func hash(data: Data) throws -> Data {
        Data(SHA256.hash(data: data))
    }
}
