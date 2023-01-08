//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2022-12-30.
//

import AsyncExtensions
import Foundation
import P2PModels
import SignalingServerClient
import Tunnel
import WebSocket

// MARK: Packer
public extension SignalingClient {
    struct Packer: Sendable {
        public typealias Pack = @Sendable (RTCPrimitive) throws -> RPCMessage
        public var pack: Pack
        public init(pack: @escaping Pack) {
            self.pack = pack
        }
    }
}

// MARK: Unpacker
public extension SignalingClient {
    struct Unpacker: Sendable {
        public typealias Unpack = @Sendable (RPCMessage) throws -> RTCPrimitive
        public var unpack: Unpack
        public init(unpack: @escaping Unpack) {
            self.unpack = unpack
        }
    }
}

public extension SignalingClient.Unpacker {

    static func radix(
        connectionSecrets: ConnectionSecrets
    ) -> Self {
        .radix(
            connectionID: connectionSecrets.connectionID,
            signalingServerEncryption: .init(key: connectionSecrets.encryptionKey)
        )
    }

    static func radix(
        connectionID: PeerConnectionID,
        signalingServerEncryption: SignalingServerEncryption
    ) -> Self {
        let unpacker = RTCPrimitiveExtractorFromRPCMessage(
            connectionID: connectionID,
            signalingServerEncryption: signalingServerEncryption
        )
        return Self(
            unpack: { try unpacker.extract(rpcMessage: $0) }
        )
    }
}

public extension SignalingClient.Packer {
    
    static func radix(
        connectionSecrets: ConnectionSecrets
    ) -> Self {
        .radix(
            connectionID: connectionSecrets.connectionID,
            signalingServerEncryption: .init(key: connectionSecrets.encryptionKey)
        )
    }
    
    static func radix(
        connectionID: PeerConnectionID,
        signalingServerEncryption: SignalingServerEncryption
    ) -> Self {
        let packer = RTCPrimitiveToMessagePacker(
            connectionID: connectionID,
            signalingServerEncryption: signalingServerEncryption
        )
        return Self(
            pack: { try packer.pack(primitive: $0) }
        )
    }
}

//
#if DEBUG
public extension SignalingClient.Unpacker {
    /// An unpacker which assumes that the `encryptedPayload` of the RPCMessage is in fact NOT
    /// encrypted and tried to JSON decode it into an RTCPrimitive.
    static var jsonDecodeOnly: Self {
        .init(unpack: { (rpcMessage: RPCMessage) in
            try _decodeWebRTCPrimitive(
                method: rpcMessage.method,
                // Assumes that the `encryptedPayload` is infact NOT encrypted.
                data: rpcMessage.encryptedPayload.data
            ) })
    }
}


public extension SignalingClient.Packer {
    /// A packer which does not perform any encryption of modification otherwise of the RTCPrimitive
    /// simply puts the JSON encoding of the RTCPrimitive as "encryptedData" (it is not encrypted) in
    /// the RPCMessage.
    static func jsonEncodeOnly(
        connectionID: PeerConnectionID = .placeholder,
        jsonEncoder: JSONEncoder = .init(),
        source: ClientSource = .mobileWallet,
        requestId: @escaping @Sendable () -> String = { UUID().uuidString }
    ) -> Self {
        .init(pack: {
            
            let json = try jsonEncoder.encode($0)
            
            let unencrypted = RPCMessageUnencrypted(
                method: $0.method,
                source: .mobileWallet,
                connectionId: connectionID,
                requestId: requestId(),
                unencryptedPayload: json
            )
            
            return RPCMessage(
                encryption: json, // performs NO encryption
                of: unencrypted
            )
        })
    }
}
#endif // DEBUG

// MARK: Transport
public extension SignalingClient {
    typealias Transport = Tunnel<URL, WebSocketState, Data, Data>
}

public extension SignalingClient {
    
    
    
    static func with(
        packer: Packer,
        unpacker: Unpacker,
        transport: Transport
    ) -> Self {
        
        actor SignalActor {
           
            private let incomingMessagesAsyncThrowingPassthroughSubject: AsyncThrowingPassthroughSubject<RadixSignalMsg.Incoming, Swift.Error>
            private var task: Task<Void, Never>?
            private let packer: Packer
            private let unpacker: Unpacker
            private let transport: Transport
            private let jsonEncoder: JSONEncoder
            private let jsonDecoder: JSONDecoder
            
            init(
                packer: Packer,
                unpacker: Unpacker,
                transport: Transport,
                jsonEncoder: JSONEncoder = .init(),
                jsonDecoder: JSONDecoder = .init()
            ) {
                self.packer = packer
                self.unpacker = unpacker
                self.transport = transport
                self.jsonEncoder = jsonEncoder
                self.jsonDecoder = jsonDecoder
                let incomingMessagesAsyncThrowingPassthroughSubject = AsyncThrowingPassthroughSubject<RadixSignalMsg.Incoming, Swift.Error>()
                self.incomingMessagesAsyncThrowingPassthroughSubject = incomingMessagesAsyncThrowingPassthroughSubject
                
                let task = Task<Void, Never> {
                    do {
                        for try await data in await transport.incomingMessages() {
                            try Task.checkCancellation()
                            let incomingMsg = try jsonDecoder.decode(RadixSignalMsg.Incoming.self, from: data)
                            incomingMessagesAsyncThrowingPassthroughSubject.send(incomingMsg)
                        }
                    } catch {
                        // FIXME: Error-handling: Should we we change this task to be throwing and (implicitly) cancel this Task by (re)throwing the error? Should we also call `transport.close`?
                        incomingMessagesAsyncThrowingPassthroughSubject.send(.failure(error))
                    }
                }
                self.task = task
            }
            
            func shutdown() async {
                await transport.close()
                task?.cancel()
            }

            func sendToRemote(rtcPrimitive: RTCPrimitive) async throws {
                let outgoingMsg = try packer.pack(rtcPrimitive)
                let data = try jsonEncoder.encode(outgoingMsg)
                try await transport.send(data)
               
                for try await result in incomingMessagesAsyncThrowingPassthroughSubject
                    .compactMap({ $0.responseForRequest?.resultOfRequest(id: outgoingMsg.requestId)})
                {
                    switch result {
                    case .success:
                        // Received message received confirmation from Signaling Server.
                        return
                    case let .failure(errorFromSignalingServer):
                        throw errorFromSignalingServer
                    }
                }
                // AsyncIterator for incoming messages finished before we got a message received
                // confirmation -> treat as error.
                struct FailedToGetConfirmationFromSignalingServer: Swift.Error {}
                throw FailedToGetConfirmationFromSignalingServer()
            }
                                                                                                   
            func rtcPrimitivesFromRemoteAsyncSequence() -> AnyAsyncSequence<RTCPrimitive> {
                incomingMessagesAsyncThrowingPassthroughSubject
                    .compactMap {
                        $0.fromRemoteClientOriginally
                    }
                    .map { [unpacker] in
                        try unpacker.unpack($0)
                    }
                    .eraseToAnyAsyncSequence()
            }
            func sessionInitiationProtocolEventsAsyncSequence() -> AnyAsyncSequence<SessionInitiationProtocolEvent> {
                incomingMessagesAsyncThrowingPassthroughSubject
                    .compactMap {
                        $0.notification
                    }
                    .eraseToAnyAsyncSequence()
            }
        }
        
        let signalActor = SignalActor(packer: packer, unpacker: unpacker, transport: transport)
        
        return Self(
            shutdown: { await signalActor.shutdown() },
            sendRTCPrimitiveToRemote: { try await signalActor.sendToRemote(rtcPrimitive: $0) },
            rtcPrimitivesFromRemoteAsyncSequence: { await signalActor.rtcPrimitivesFromRemoteAsyncSequence() },
            sessionInitiationProtocolEventsAsyncSequence: { await signalActor.sessionInitiationProtocolEventsAsyncSequence() }
        )
    }
}

// MARK: SignalingClient.Transport
public extension SignalingClient.Transport where ID == URL, ReadyState == WebSocketState, OutgoingMessage == Data, IncomingMessage == Data {
    
    static func webSocket(url: URL) -> Self {
        let wsActor = WebSocketActor(url: url)
        return Self.multicast(
            getID: url,
            readyStateAsyncSequence: {
                await wsActor.readyStateAsyncSequence()
            },
            incomingMessagesAsyncSequence: {
                await wsActor.incomingMessageAsyncSequence().compactMap {
                    switch $0 {
                    case let .data(data): return data
                    case let .string(string): return Data(string.utf8)
                    @unknown default:
                        debugPrint("Unknown websocket message type: \($0)")
                        return nil
                    }
                }
            },
            send: {
                try await wsActor.send(data: $0)
            },
            close: {
                await wsActor.close()
            })
    }
}
