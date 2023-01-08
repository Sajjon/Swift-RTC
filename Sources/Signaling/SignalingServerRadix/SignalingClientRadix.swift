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

public extension SignalingClient {
    
    static func radix(
        connectionSecrets: ConnectionSecrets,
        transport: Transport
    ) -> Self {
        Self.radix(
            packer: .radix(connectionSecrets: connectionSecrets),
            unpacker: .radix(connectionSecrets: connectionSecrets),
            transport: transport
        )
    }
}

internal extension SignalingClient {
    static func radix(
        packer: Packer,
        unpacker: Unpacker,
        transport: Transport,
        requireMessageSentConfirmationFromSignalingServerWhenSending: Bool = true
    ) -> Self {
        
        let signalActor = SignalActor(
            packer: packer,
            unpacker: unpacker,
            transport: transport,
            requireMessageSentConfirmationFromSignalingServerWhenSending: requireMessageSentConfirmationFromSignalingServerWhenSending
        )
        
        return Self(
            shutdown: { await signalActor.shutdown() },
            sendToRemote: SendToRemoteFunctionType {
                try await signalActor.sendToRemote(rtcPrimitive: $0)
            },
            rtcPrimitivesFromRemoteAsyncSequence: { await signalActor.rtcPrimitivesFromRemoteAsyncSequence() },
            sessionInitiationProtocolEventsAsyncSequence: { await signalActor.sessionInitiationProtocolEventsAsyncSequence() }
        )
    }
}



/* internal for tests but rather private */
internal extension SignalingClient {
    
    // only internal for tests
    actor SignalActor {
        
        private let incomingMessagesAsyncThrowingPassthroughSubject: AsyncThrowingPassthroughSubject<RadixSignalMsg.Incoming, Swift.Error>
        private var task: Task<Void, Never>?
        private let packer: Packer
        private let unpacker: Unpacker
        private let transport: Transport
        private let jsonEncoder: JSONEncoder
        private let jsonDecoder: JSONDecoder
        
        // Useful for e.g. testing to set this to `false`.
        private let requireMessageSentConfirmationFromSignalingServerWhenSending: Bool
        
        init(
            packer: Packer,
            unpacker: Unpacker,
            transport: Transport,
            jsonEncoder: JSONEncoder = .init(),
            jsonDecoder: JSONDecoder = .init(),
            requireMessageSentConfirmationFromSignalingServerWhenSending: Bool
        ) {
            self.requireMessageSentConfirmationFromSignalingServerWhenSending = requireMessageSentConfirmationFromSignalingServerWhenSending
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
                    print("✨❌ failed to json decode? error: \(String(describing: error))")
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
        
        // Only reason we return outgoing message is for tests
        @discardableResult
        func sendToRemote(rtcPrimitive: RTCPrimitive) async throws -> Data {
            let outgoingMsg = try packer.pack(rtcPrimitive)
            let outgoingJSONData = try jsonEncoder.encode(outgoingMsg)
            try await transport.send(outgoingJSONData)
            guard requireMessageSentConfirmationFromSignalingServerWhenSending else {
                // skip waiting for message confirmation
                return outgoingJSONData // returned for tests
            }
            for try await result in incomingMessagesAsyncThrowingPassthroughSubject
                .compactMap({ $0.responseForRequest?.resultOfRequest(id: outgoingMsg.requestId)})
            {
                switch result {
                case .success:
                    // Received message received confirmation from Signaling Server.
                    return outgoingJSONData  // returned for tests
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
}

