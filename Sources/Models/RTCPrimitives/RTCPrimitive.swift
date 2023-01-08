//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-27.
//

import Foundation

public enum RTCPrimitive:
    Sendable,
        Hashable,
        Encodable
 /* NOT `Decodable` because decoding requires externally provided discriminator, see bottom of file */
{
    case offer(Offer)
    case answer(Answer)
    case addICE(ICECandidate)
    case removeICEs([ICECandidate])
}

public extension RTCPrimitive {
    
    enum Discriminator: String, Sendable, Hashable, CustomStringConvertible {
        case offer, answer, addICE, removeICEs
    }
    
    var discriminator: Discriminator {
        switch self {
        case .offer: return .offer
        case .answer: return .answer
        case .addICE: return .addICE
        case .removeICEs: return .removeICEs
        }
    }
    
    var offer: Offer? {
        guard case let .offer(offer) = self else {
            return nil
        }
        return offer
    }
    var answer: Answer? {
        guard case let .answer(answer) = self else {
            return nil
        }
        return answer
    }
    
    var addICE: ICECandidate? {
        guard case let .addICE(ice) = self else {
            return nil
        }
        return ice
    }
    
    var removeICEs: [ICECandidate]? {
        guard case let .removeICEs(ices) = self else {
            return nil
        }
        return ices
    }
}

// MARK: Encodable
public extension RTCPrimitive {
    
    func encode(to encoder: Encoder) throws {
        var singleValueContainer = encoder.singleValueContainer()
        switch self {
        case let .offer(value):
            try singleValueContainer.encode(value)
        case let .answer(value):
            try singleValueContainer.encode(value)
        case let .removeICEs(values):
            try singleValueContainer.encode(values)
        case let .addICE(value):
            try singleValueContainer.encode(value)
        }
    }
}

// MARK: Decode with Discriminator
public extension RTCPrimitive {
    static func decode(
        method: RPCMethod,
        data: Data,
        jsonDecoder: JSONDecoder = .init()
    ) throws -> Self {
        switch method {
        case .offer:
            return try .offer(jsonDecoder.decode(Offer.self, from: data))
        case .answer:
            return try .answer(jsonDecoder.decode(Answer.self, from: data))
        case .addICE:
            return try .addICE(jsonDecoder.decode(ICECandidate.self, from: data))
        case .removeICEs:
            return try .removeICEs(jsonDecoder.decode([ICECandidate].self, from: data))
        }
    }
}

