public enum PeerConnectionState: String, Sendable, Hashable, Codable, CustomStringConvertible {
    case closed, new, connecting, connected, disconnected, failed
}
