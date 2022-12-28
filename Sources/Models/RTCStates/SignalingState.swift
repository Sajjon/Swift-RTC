//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-28.
//

import Foundation

public enum SignalingState: String, Sendable, Hashable, CustomStringConvertible {
    case closed, stable, haveLocalOffer, haveLocalPrAnswer, haveRemoteOffer, haveRemotePrAnswer
}
