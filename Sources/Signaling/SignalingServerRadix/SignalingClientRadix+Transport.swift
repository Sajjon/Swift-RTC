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
            }
        )
        
    }
}
