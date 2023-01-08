//
//  LoremIpsumGenerator.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-09-06.
//

import Foundation

public struct LoremIpsumGenerator {
    public var generate: GenerateLoremIpsum
}

public extension LoremIpsumGenerator {
    typealias ByteCount = Int
    typealias CacheKey = String
    typealias GenerateLoremIpsum = @Sendable (ByteCount, CacheKey) async -> String
}

public extension LoremIpsumGenerator {
    static let sizesInKB: [Int] = [100, 250, 500, 1_000, 5_000, 10_000]
    static let sizesInBytes: [Int] = sizesInKB.map {
        $0 * 1000
    }
}

public extension LoremIpsumGenerator {

    func generate(kiloBytes: Int) async -> String {
        await generate(kiloBytes * 1000, "\(kiloBytes)kb")
    }
    
    func memoize() async {
        await withTaskGroup(of: Void.self) { group in
            for kiloBytes in Self.sizesInKB {
                group.addTask {
                    _ = await self.generate(kiloBytes: kiloBytes)
                }
            }
            await group.waitForAll()
        }
    }
    
}
