public enum SignalingState: String, Sendable, Hashable, CustomStringConvertible {
    case closed, stable, haveLocalOffer, haveLocalPrAnswer, haveRemoteOffer, haveRemotePrAnswer
}
