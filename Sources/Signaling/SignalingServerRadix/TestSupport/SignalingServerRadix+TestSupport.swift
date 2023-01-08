#if DEBUG
import AsyncExtensions
import Foundation
import P2PModels
import SignalingServerClient
import Tunnel
import WebSocket

public extension SignalingClient {
    
    static func passthrough(
        transport: Transport,
        connectionID: PeerConnectionID = .placeholder,
        jsonEncoder: JSONEncoder = .init(),
        source: ClientSource,
        requireMessageSentConfirmationFromSignalingServerWhenSending: Bool = false,
        requestId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) -> Self {
        Self.radix(
            packer: .jsonEncodeOnly(
                connectionID: connectionID,
                jsonEncoder: jsonEncoder,
                source: source,
                requestId: requestId
            ),
            unpacker: .jsonDecodeOnly,
            transport: transport,
            requireMessageSentConfirmationFromSignalingServerWhenSending: requireMessageSentConfirmationFromSignalingServerWhenSending
        )
    }
    
    static func passthrough(
        connectionID: PeerConnectionID = .placeholder,
        jsonEncoder: JSONEncoder = .init(),
        jsonDecoder: JSONDecoder = .init(),
        callerSource: ClientSource = .mobileWallet,
        answererSource: ClientSource = .browserExtension,
        requestId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) -> (caller: Self, answerer: Self) {
        
        let (callerTransport, answererTransport) = Tunnel.emulatingServerBetween()

        let caller = Self.passthrough(
            transport: callerTransport,
            connectionID: connectionID,
            jsonEncoder: jsonEncoder,
            source: callerSource,
            requestId: requestId
        )

        let answerer = Self.passthrough(
            transport: answererTransport,
            connectionID: connectionID,
            jsonEncoder: jsonEncoder,
            source: answererSource,
            requestId: requestId
        )
        
        return (
            caller: caller,
            answerer: answerer
        )
        
    }
    

}


public extension SignalingClient.Transport {

    static func multicastPassthrough<IncomingMessagesAsync>(
        incoming: IncomingMessagesAsync,
        send: @escaping Send,
        close: Close? = { print("closed called") }
    ) -> Self where   IncomingMessagesAsync: AsyncSequence & Sendable,
                      IncomingMessagesAsync.AsyncIterator: Sendable,
                      IncomingMessagesAsync.Element == IncomingMessage {
        Self.multicast(
            getID: { fatalError("No ID") }(),
            readyStateAsyncSequence: AsyncStream(unfolding: { fatalError("No ready state") }),
            incomingMessagesAsyncSequence: incoming,
            send: send,
            close: { await close?() }
        )
    }
    
    static func emulatingServerBetween() -> (caller: Self, answerer: Self) {
        
        let fromCallerSubject = AsyncPassthroughSubject<Data>()
        let fromAnswererSubject = AsyncPassthroughSubject<Data>()
        
        @Sendable func transform(outgoing data: Data) throws -> Data {
            let jsonDecoder = JSONDecoder()
            let jsonEncoder = JSONEncoder()
            let rpc = try jsonDecoder.decode(RPCMessage.self, from: data)
            let incoming = RadixSignalMsg.Incoming.fromRemoteClientOriginally(rpc)
            let transformed = try jsonEncoder.encode(incoming)
            return transformed
        }
        
        let caller: Self = .multicastPassthrough(
            incoming: fromAnswererSubject.eraseToAnyAsyncSequence(),
            send: {
                let transformed = try transform(outgoing: $0)
                fromCallerSubject.send(transformed)
            }
        )
        let answerer: Self = .multicastPassthrough(
            incoming: fromCallerSubject.eraseToAnyAsyncSequence(),
            send: {
                let transformed = try transform(outgoing: $0)
                fromAnswererSubject.send(transformed)
            }
        )
        return (caller, answerer)
        
    }
}


#endif // DEBUG
