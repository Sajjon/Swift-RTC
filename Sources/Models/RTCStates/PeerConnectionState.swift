public enum PeerConnectionState: String, Sendable, Hashable, CustomStringConvertible {
    case closed, new, connecting, connected, disconnected, failed
}
