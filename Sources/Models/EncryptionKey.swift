//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-09-09.
//

import Foundation
import CryptoKit

// `Data` is `Sendable`, but `CryptoKit.SymmetricKey` (`EncryptionKey`) is not.
public struct EncryptionKey: Sendable, Hashable, Codable {
    public let data: HexCodable
    public init(_ data: HexCodable) throws {
        guard data.count == Self.byteCount else {
            loggerGlobal.error("EncryptionKey:data bad length: \(data.count)")
            throw Error.incorrectByteCount(got: data.count, butExpected: Self.byteCount)
        }
        self.data = data
    }
    public init(data: Data) throws {
        try self.init(.init(data: data))
    }
}
public extension EncryptionKey {
    enum Error: Swift.Error {
        case incorrectByteCount(got: Int, butExpected: Int)
    }
    
    static let byteCount = 32
    var symmetric: SymmetricKey {
        .init(data: data.data)
    }
}
