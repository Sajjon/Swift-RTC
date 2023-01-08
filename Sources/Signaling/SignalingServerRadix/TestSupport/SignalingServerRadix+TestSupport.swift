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
    

    static func emulatingServer<IncomingMessagesAsync>(
        incoming: IncomingMessagesAsync,
        outgoingSubject: AsyncPassthroughSubject<Data>
    ) -> Self
    where
IncomingMessagesAsync: AsyncSequence & Sendable,
IncomingMessagesAsync.AsyncIterator: Sendable,
IncomingMessagesAsync.Element == IncomingMessage
    {
        @Sendable func transform(outgoing data: Data) throws -> Data {
            let jsonDecoder = JSONDecoder()
            let jsonEncoder = JSONEncoder()
          
            do {
                // Our SignalingServer is either sending primitives packed
                // as RPCMessage, we transform those as if they have been
                // sent via Signaling Server, i.e:
                // we transform `RPCMessage` -> `FromRemoteClientOriginally`
                //
                // or...
                let rpc = try jsonDecoder.decode(RPCMessage.self, from: data)
                let incoming = RadixSignalMsg.Incoming.fromRemoteClientOriginally(rpc)
                let transformed = try jsonEncoder.encode(incoming)
                return transformed
            } catch {
                // ... or we have used the same transport from a unit test to
                // send a SessionInitialisationEvent - a.k.a. `RadixSignalMsg.Incoming`
                // of case `fromSignalingServerItself`.
                let fromSignaling = try jsonDecoder.decode(RadixSignalMsg.Incoming.self, from: data)
                switch fromSignaling {
                case .fromSignalingServerItself:
                    return data // as is
                default:
                    throw error
                }
            }
        }
        
        return .multicastPassthrough(
            incoming: incoming,
            send: {
                let transformed = try transform(outgoing: $0)
                outgoingSubject.send(transformed)
            }
        )
    }
    
    static func emulatingServerBetween() -> (caller: Self, answerer: Self) {
        
        let fromCallerSubject = AsyncPassthroughSubject<Data>()
        let fromAnswererSubject = AsyncPassthroughSubject<Data>()
        
        let caller: Self =  .emulatingServer(
            incoming: fromAnswererSubject.eraseToAnyAsyncSequence(),
            outgoingSubject: fromCallerSubject
        )
        let answerer: Self = .emulatingServer(
            incoming: fromCallerSubject,
            outgoingSubject: fromAnswererSubject
        )

        return (caller, answerer)
        
    }
}


#endif // DEBUG
