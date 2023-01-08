import Foundation
import AsyncExtensions
import P2PModels

extension AsyncStream.Iterator: @unchecked Sendable where AsyncStream.Iterator.Element: Sendable {}

public struct Tunnel<ID, ReadyState, IncomingMessage, OutgoingMessage>: Disconnecting where
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

    typealias GetID = @Sendable () -> ID
    typealias ReadyStateUpdates = @Sendable () async -> AnyAsyncSequence<ReadyState>
    typealias IncomingMessages = @Sendable () async -> AnyAsyncSequence<IncomingMessage>
    typealias Send = @Sendable (OutgoingMessage) async throws -> Void
    typealias Close = @Sendable () async -> Void
    
    typealias In = IncomingMessage
    typealias Out = OutgoingMessage
}

// MARK: Equatable
public extension Tunnel {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: Hashable
public extension Tunnel {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: Identifiable
public extension Tunnel {
    var id: ID { getID() }
}

// MARK: Disconnecting
public extension Tunnel {
    func disconnect() async {
        await close()
    }
}

// MARK: Encoder
public extension Tunnel {
    struct Encoder: Sendable {
        public typealias Encode = @Sendable (OutgoingMessage) async throws -> Data
        public var encode: Encode
        public init(encode: @escaping Encode) {
            self.encode = encode
        }
    }
}

// MARK: Decoder
public extension Tunnel {
    struct Decoder: Sendable {
        public typealias Decode = @Sendable (Data) async throws -> IncomingMessage
        public var decode: Decode
        public init(decode: @escaping Decode) {
            self.decode = decode
        }
    }
}


public extension Tunnel {
    
    static func multicast<ReadyStateAsync, IncomingMessagesAsync>(
        getID: @escaping @autoclosure @Sendable () -> ID,
        readyStateAsyncSequence: @escaping @Sendable () async -> ReadyStateAsync,
        incomingMessagesAsyncSequence: @escaping @Sendable () async -> IncomingMessagesAsync,
        send: @escaping Send,
        close: @escaping Close
    ) -> Self where
        ReadyStateAsync: AsyncSequence & Sendable,
        ReadyStateAsync.AsyncIterator: Sendable,
        ReadyStateAsync.Element == ReadyState,
        IncomingMessagesAsync: AsyncSequence & Sendable,
        IncomingMessagesAsync.AsyncIterator: Sendable,
        IncomingMessagesAsync.Element == IncomingMessage
    {
        let reaadyStateMulticastSubject = AsyncThrowingPassthroughSubject<ReadyState, Error>()
        
        let incomingMulticastSubject = AsyncThrowingPassthroughSubject<IncomingMessage, Error>()
        
        return Self(
            getID: getID,
            readyStateUpdates: {
                await readyStateAsyncSequence()
                .multicast(reaadyStateMulticastSubject)
                .autoconnect()
                .eraseToAnyAsyncSequence()
            },
            incomingMessages: {
                await incomingMessagesAsyncSequence()
                .multicast(incomingMulticastSubject)
                .autoconnect()
                .eraseToAnyAsyncSequence()
            },
            send: send,
            close: close
        )
    }
    
    static func multicast<ReadyStateAsync, IncomingMessagesAsync>(
        getID: @escaping @autoclosure @Sendable () -> ID,
        readyStateAsyncSequence: ReadyStateAsync,
        incomingMessagesAsyncSequence: IncomingMessagesAsync,
        send: @escaping Send,
        close: @escaping Close
    ) -> Self where
        ReadyStateAsync: AsyncSequence & Sendable,
        ReadyStateAsync.AsyncIterator: Sendable,
        ReadyStateAsync.Element == ReadyState,
        IncomingMessagesAsync: AsyncSequence & Sendable,
        IncomingMessagesAsync.AsyncIterator: Sendable,
        IncomingMessagesAsync.Element == IncomingMessage
    {
        Self.multicast(
            getID: getID(),
            readyStateAsyncSequence: {
                readyStateAsyncSequence
            },
            incomingMessagesAsyncSequence: {
                incomingMessagesAsyncSequence
            },
            send: send,
            close: close
        )
    }
    
    static func multicast(
        getID: @escaping @autoclosure @Sendable () -> ID,
        unfoldingReadyState: @escaping @Sendable () async -> ReadyState?,
        unfoldingIncomingMessage: @escaping @Sendable () async -> IncomingMessage?,
        send: @escaping Send,
        close: @escaping Close
    ) -> Self {
        
        Self.multicast(
            getID: getID(),
            readyStateAsyncSequence: AsyncStream(
                unfolding: unfoldingReadyState
            ),
            incomingMessagesAsyncSequence: AsyncStream(
                unfolding: unfoldingIncomingMessage
            ),
            send: send,
            close: close
        )
    }
}

#if DEBUG

// MARK: Encoder Passthrough
public extension Tunnel.Encoder where Tunnel.In == Data, Tunnel.Out == Data {
    static var passthrough: Self {
        Self(encode: { $0 })
    }
}

// MARK: Decoder Passthrough
public extension Tunnel.Decoder where Tunnel.In == Data, Tunnel.Out == Data {
    static var passthrough: Self {
        Self(decode: { $0 })
    }
}
#endif
