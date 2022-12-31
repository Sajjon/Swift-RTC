import Foundation
import AsyncExtensions

public struct Tunnel<ID, ReadyState, IncomingMessage, OutgoingMessage>: Sendable
where
ID: Sendable & Equatable,
ReadyState: Sendable & Equatable,
IncomingMessage: Sendable & Equatable,
OutgoingMessage: Sendable & Equatable
{
    public var getID: GetID
    public var readyStateUpdates: ReadyStateUpdates
    public var incomingMessages: IncomingMessages
    public var send: Send
    public var close: Close
    
    public init(
        getID: @escaping GetID,
        readyStateUpdates: @escaping ReadyStateUpdates,
        incomingMessages: @escaping IncomingMessages,
        send: @escaping Send,
        close: @escaping Close
    ) {
        self.getID = getID
        self.readyStateUpdates = readyStateUpdates
        self.incomingMessages = incomingMessages
        self.send = send
        self.close = close
    }
}

public extension Tunnel {
    typealias GetID = @Sendable () -> ID
    typealias ReadyStateUpdates = @Sendable () async throws ->
    AnyAsyncSequence<ReadyState>
    typealias IncomingMessages = @Sendable () async throws ->
    AnyAsyncSequence<IncomingMessage>
    typealias Send = @Sendable (OutgoingMessage) async throws -> Void
    typealias Close = @Sendable () async throws -> Void
    
    typealias In = IncomingMessage
    typealias Out = OutgoingMessage
}

public extension Tunnel.Encoder where Tunnel.In == Data, Tunnel.Out == Data {
    static var passthrough: Self {
        Self(encode: { $0 })
    }
}
public extension Tunnel.Decoder where Tunnel.In == Data, Tunnel.Out == Data {
    static var passthrough: Self {
        Self(decode: { $0 })
    }
}

public extension Tunnel {
    struct Encoder: Sendable {
        public typealias Encode = @Sendable (OutgoingMessage) async throws -> Data
        public var encode: Encode
        public init(encode: @escaping Encode) {
            self.encode = encode
        }
    }
    struct Decoder: Sendable {
        public typealias Decode = @Sendable (Data) async throws -> IncomingMessage
        public var decode: Decode
        public init(decode: @escaping Decode) {
            self.decode = decode
        }
    }
}
