public enum SignalingState: String, Sendable, Hashable, Codable, CustomStringConvertible {
    case closed, stable, haveLocalOffer, haveLocalPrAnswer, haveRemoteOffer, haveRemotePrAnswer
}
