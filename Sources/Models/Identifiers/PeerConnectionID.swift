//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public struct PeerConnectionID: Sendable, Hashable, Codable, CustomStringConvertible {
    public let data: HexCodable
  
    public init(data: Data) throws {
        guard data.count == Self.byteCount else {
            loggerGlobal.error("ConnectionPassword:data bad length: \(data.count)")
            throw Error.incorrectByteCount(got: data.count, butExpected: Self.byteCount)
        }
        self.data = HexCodable(data: data)
    }
    
}

public extension PeerConnectionID {
    var description: String {
        data.hex()
    }
}

public extension PeerConnectionID {
    enum Error: Swift.Error {
        case incorrectByteCount(got: Int, butExpected: Int)
    }
    
    static let byteCount = 32

}

public extension PeerConnectionID {
    func hex(options: Data.HexEncodingOptions = []) -> String {
        data.hex(options: options)
    }
}

#if DEBUG
extension PeerConnectionID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        var bytes = value.bytes
        while bytes.count < Self.byteCount {
            bytes = [0x00] + bytes
        }
        try! self.init(data: Data(bytes))
    }
}
public extension PeerConnectionID {
    static let placeholder = try! Self(data: .deadbeef32Bytes)
}
#endif // DEBUG
