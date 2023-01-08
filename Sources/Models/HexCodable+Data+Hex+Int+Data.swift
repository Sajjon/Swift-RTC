//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-08.
//

import Foundation

public extension FixedWidthInteger {
    var data: Data {
        let data = withUnsafeBytes(of: self) { Data($0) }
        return data
    }

    var bytes: [UInt8] {
        [UInt8](data)
    }
}

public extension Data {
    static let deadbeef32Bytes = try! Data(hex: .deadbeef32Bytes)
    struct HexEncodingOptions: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hex(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

    init(hex: String) throws {
        struct Fail: Swift.Error {}
        guard hex.count.isMultiple(of: 2) else {
            throw Fail()
        }

        let chars = hex.map { $0 }
        let bytes = stride(from: 0, to: chars.count, by: 2)
            .map { String(chars[$0]) + String(chars[$0 + 1]) }
            .compactMap { UInt8($0, radix: 16) }

        guard hex.count / bytes.count == 2 else {
            throw Fail()
        }
        self.init(bytes)
    }
}

public extension String {
    static let deadbeef32Bytes = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
}

public struct HexCodable: Sendable, Hashable, Codable {
    public let data: Data
    public init(data: Data) {
        self.data = data
    }
}

public extension HexCodable {
    func hex(options: Data.HexEncodingOptions = []) -> String {
        data.hex(options: options)
    }

    static let deadbeef32Bytes = Self(data: .deadbeef32Bytes)
    var count: Int { data.count }
}

#if DEBUG
public extension Data {
    
    func printFormatedJSON() -> String {
        if let json = try? JSONSerialization.jsonObject(with: self, options: .mutableContainers),
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        {
            return  String(decoding: jsonData, as: UTF8.self)
        } else {
            fatalError("Malformed JSON")
        }
    }
}
#endif
