//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-08.
//

import AsyncExtensions
import Foundation
import P2PModels
import SignalingServerClient
import Tunnel
import WebSocket

// MARK: Transport
public extension SignalingClient {
    typealias Transport = Tunnel<URL, WebSocketState, Data, Data>
}

public extension SignalingClient.Transport {
    
    static func webSocket(
        peerConnectionID: PeerConnectionID,
        url: URL
    ) -> Self {
        
        Self.multicast(
            getID: url,
            readyStateAsyncSequence: {
                let aSeq: AnyAsyncSequence<WebSocketState> = await WebSocketActor.shared.open(id: peerConnectionID, url: url, protocols: []).eraseToAnyAsyncSequence()
                return aSeq
            },
            incomingMessagesAsyncSequence: {
                try await WebSocketActor.shared.receive(id: peerConnectionID)
                    .map { (result: TaskResult<WebSocketActor.Message>) throws -> WebSocketActor.Message in
                        switch result {
                        case let .failure(error):
                            throw error
                        case let .success(message):
                            return message
                        }
                    }
                    .map { (msg: WebSocketActor.Message) -> Data in
                        switch msg {
                        case let .data(data): return data
                        case let .string(string): return Data(string.utf8)
                        }
                    }
                    .eraseToAnyAsyncSequence()
            },
            send: {
                try await WebSocketActor.shared.send(id: peerConnectionID, message: .data($0))
            },
            close: {
                try! await WebSocketActor.shared.close(
                    id: peerConnectionID,
                    with: .goingAway,
                    reason: Data("SignalingClient.Transport-close".utf8)
                )
            }
        )
        
    }
}
