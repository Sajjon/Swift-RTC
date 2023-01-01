import Foundation
import AsyncExtensions

extension AsyncStream.Iterator: @unchecked Sendable where AsyncStream.Iterator.Element: Sendable {}

public struct Tunnel<ID, ReadyState, IncomingMessage, OutgoingMessage>: Disconnecting
where
ID: Sendable & Hashable,
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
    func disconnect() async {
        await close()
    }
    var id: ID { getID() }
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    typealias GetID = @Sendable () -> ID
    typealias ReadyStateUpdates = @Sendable () async throws ->
    AnyAsyncSequence<ReadyState>
    typealias IncomingMessages = @Sendable () async throws ->
    AnyAsyncSequence<IncomingMessage>
    typealias Send = @Sendable (OutgoingMessage) async throws -> Void
    typealias Close = @Sendable () async -> Void
    
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


public extension Tunnel {
    
    static func live(
        getID: @escaping @autoclosure @Sendable () -> ID,
        readyStateAsyncStream: AsyncStream<ReadyState>,
        incomingMessagesAsyncStream: AsyncStream<IncomingMessage>,
        send: @escaping Send,
        close: @escaping Close
    ) -> Self {
        
        let reaadyStateMulticastSubject = AsyncThrowingPassthroughSubject<ReadyState, Error>()
        let incomingMulticastSubject = AsyncThrowingPassthroughSubject<IncomingMessage, Error>()
        
        return Self(
            getID: getID,
            readyStateUpdates: {
                readyStateAsyncStream
                .multicast(reaadyStateMulticastSubject)
                .autoconnect()
                .eraseToAnyAsyncSequence()
            },
            incomingMessages: {
                incomingMessagesAsyncStream
                .multicast(incomingMulticastSubject)
                .autoconnect()
                .eraseToAnyAsyncSequence()
            },
            send: send,
            close: close
        )
    }
    
    static func live(
        getID: @escaping @autoclosure @Sendable () -> ID,
        unfoldingReadyState: @escaping @Sendable () async -> ReadyState?,
        unfoldingIncomingMessage: @escaping @Sendable () async -> IncomingMessage?,
        send:  @escaping Send,
        close:  @escaping Close
    ) -> Self {
        
        Self.live(
            getID: getID(),
            readyStateAsyncStream: AsyncStream(
                    unfolding: unfoldingReadyState
                ),
            incomingMessagesAsyncStream:
                AsyncStream(
                    unfolding: unfoldingIncomingMessage
                ),
            send: send,
            close: close
        )
    }
}
