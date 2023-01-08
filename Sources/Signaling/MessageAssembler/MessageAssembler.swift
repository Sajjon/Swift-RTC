//
//  File.swift
//
//
//  Created by Alexander Cyon on 2022-08-18.
//

import Foundation
import P2PModels

public final class ChunkedMessagePackageAssembler: Sendable {
    public init() {}
}

public struct AssembledMessage: Sendable, Hashable {
    public let messageContent: Data
    public let messageHash: Data
}

public extension ChunkedMessagePackageAssembler {
    enum Error: LocalizedError, Sendable, Hashable {
        case foundReceiveMessageError(ChunkedMessageReceiveError)
        case parseError(ParseError)
        case messageByteCountMismatch(got: Int, butMetaDataPackageStated: Int)
        case hashMismatch(calculated: String, butExpected: String)
        
        public enum ParseError: LocalizedError, Sendable, Hashable {
            case noPackages
            case noMetaDataPackage
            case foundMultipleMetaDataPackages
            case metaDataPackageStatesZeroChunkPackages
            case invalidNumberOfChunkedPackages(got: Int, butMetaDataPackageStated: Int)
            
            /// E.g. if we only received chunked packages with indices of: `[1, 2, 3]` (instead of `[0, 1, 2]`).
            /// We do not throw this error if we receive chunked packages unordered, i.e. indices of `[1, 0, 2]` is
            /// allowed (however, inaccurate) because we can simple correct the order.
            case incorrectIndicesOfChunkedPackages
        }
    }
    
    func assemble(packages: [ChunkedMessagePackage]) throws -> AssembledMessage {
        guard
            !packages.isEmpty
        else {
            loggerGlobal.error("'packages' array is empty, not allowed.")
            throw Error.parseError(.noPackages)
        }
        
        if let receiveMessageError = packages.compactMap({ $0.receiveMessageError }).first {
            loggerGlobal.error("'packages' contained receiveMessageError: \(String(describing: receiveMessageError))")
            throw Error.foundReceiveMessageError(receiveMessageError)
        }
        
        let filterMetaDataPkg: (ChunkedMessagePackage) -> Bool = { $0.packageType == .metaData }
        
        guard
            let indexOfMetaData = packages.firstIndex(where: filterMetaDataPkg)
        else {
            loggerGlobal.error("No MetaData package in 'packages', which is required.")
            throw Error.parseError(.noMetaDataPackage)
        }
        
        let metaDataWasFirstInList = indexOfMetaData == 0
        if !metaDataWasFirstInList {
            loggerGlobal.warning("MetaData was not first package in array, either other client are sending packages in incorrect order, or we have received them over the communication channel in the wrong order. We will try to reorder them.")
        }
        
        guard
            packages.filter(filterMetaDataPkg).count == 1
        else {
            loggerGlobal.error("Found multiple MetaData packages, this is invalid.")
            throw Error.parseError(.foundMultipleMetaDataPackages)
        }
        
        guard
            case let .metaData(metaDataPackage) = packages[indexOfMetaData]
        else {
            let errorMsg = "Have asserted that package at index: \(indexOfMetaData) IS a MetaData package, bad logic somewhere."
            loggerGlobal.error(.init(stringLiteral: errorMsg))
            throw Error.parseError(.foundMultipleMetaDataPackages)
        }
        
        guard metaDataPackage.chunkCount > 0 else {
            loggerGlobal.error("MetaData package states a chunkCount of 0. This is not allowed. Client is sending corrupt data.")
            throw Error.parseError(.metaDataPackageStatesZeroChunkPackages)
        }
        
        let expectedHash = metaDataPackage.hashOfMessage.data
        let chunkCount = metaDataPackage.chunkCount
        
        
        // Mutable since we allow incorrect ordering of chunked packages, and sort on index.
        var chunkedPackages: [ChunkedMessageChunkPackage] = packages.compactMap { $0.chunk }
        
        guard chunkedPackages.count == chunkCount else {
            loggerGlobal.error("Invalid number of chunked packages, metadata package states: #\(chunkCount) but got: #\(chunkedPackages.count).")
            throw Error.parseError(.invalidNumberOfChunkedPackages(
                got: chunkedPackages.count,
                butMetaDataPackageStated: chunkCount
            ))
        }
        
        assert(chunkedPackages.count > 0, "We should have check that number of chunked packages are greater than zero above. Code below will fail otherwise.")
        
        let indices = chunkedPackages.map { $0.chunkIndex }
        let expectedOrderOfIndices = ((0..<chunkCount).map { $0 })
        let indicesDifference = Set(indices).symmetricDifference(Set(expectedOrderOfIndices))
        guard indicesDifference.isEmpty  else {
            loggerGlobal.error("Incorrect indices of chunked packages, got difference: \(indicesDifference)")
            throw Error.parseError(.incorrectIndicesOfChunkedPackages)
        }
        
        let chunkedPackagesWereOrdered = indices == expectedOrderOfIndices
        if !chunkedPackagesWereOrdered {
            // Chunked packages are not ordered properly
            loggerGlobal.warning("Chunked packages are not ordered, either other client are sending packages in incorrect order, or we have received them over the communication channel in the wrong order. We will reorder them.")
            chunkedPackages.sort(by: <)
        }
        
        let message = chunkedPackages.map { $0.chunkData }.reduce(Data(), +)
        
        guard message.count == metaDataPackage.messageByteCount else {
            loggerGlobal.error("Re-assembled message has #\(message.count) bytes, but MetaData package stated a message byte count of: #\(metaDataPackage.messageByteCount) bytes.")
            throw Error.messageByteCountMismatch(
                got: message.count,
                butMetaDataPackageStated: metaDataPackage.messageByteCount
            )
        }
        
        let hash = try RadixHasher.hash(data: message)
        guard hash == expectedHash else {
            let hashHex = hash.hex()
            let expectedHashHex = expectedHash.hex()
            loggerGlobal.critical("Hash of re-assembled message differs from expected one. Calculated hash: '\(hashHex)', but MetaData package stated: '\(expectedHashHex)'.")
            throw Error.hashMismatch(
                calculated: hashHex,
                butExpected: expectedHashHex
            )
        }
        
        return AssembledMessage(messageContent: message, messageHash: hash)
    }
}
