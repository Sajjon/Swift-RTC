//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-27.
//

import Foundation

public enum RTCPrimitive: Sendable, Hashable, Codable {
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
