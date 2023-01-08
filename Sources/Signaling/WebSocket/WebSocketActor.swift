// MIT License
//
// Copyright (c) 2020 Point-Free, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import P2PModels
import AsyncExtensions

// MARK: WebSocketActor
public final actor WebSocketActor: GlobalActor {
    public struct ID: Sendable, Hashable {
        public let peerConnectionID: PeerConnectionID
        public let clientSource: ClientSource
        public init(peerConnectionID: PeerConnectionID, clientSource: ClientSource) {
            self.peerConnectionID = peerConnectionID
            self.clientSource = clientSource
        }
    }
    typealias Dependencies = (socket: URLSessionWebSocketTask, delegate: Delegate)
    var dependencies: [ID: Dependencies] = [:]
    
    public static let shared = WebSocketActor()
}

// MARK: Delegate
internal extension WebSocketActor {
    
    final class Delegate: NSObject, URLSessionWebSocketDelegate {
        var continuation: AsyncStream<WebSocketState>.Continuation?
        
        func urlSession(
            _: URLSession,
            webSocketTask _: URLSessionWebSocketTask,
            didOpenWithProtocol protocol: String?
        ) {
            self.continuation?.yield(.connected)
        }
        
        func urlSession(
            _: URLSession,
            webSocketTask _: URLSessionWebSocketTask,
            didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
            reason: Data?
        ) {
            self.continuation?.yield(.closed(closeCode.swiftify()))
            self.continuation?.finish()
        }
    }
}

// MARK: Message
public extension WebSocketActor {
    enum Message: Sendable, Equatable {
        struct Unknown: Error {}
        
        case data(Data)
        case string(String)
        
        init(_ message: URLSessionWebSocketTask.Message) throws {
            switch message {
            case let .data(data): self = .data(data)
            case let .string(string): self = .string(string)
            @unknown default: throw Unknown()
            }
        }
    }
}

public extension WebSocketActor {
    
    func open(id: ID, url: URL, protocols: [String] = []) -> AsyncStream<WebSocketState> {
        let delegate = Delegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let socket = session.webSocketTask(with: url, protocols: protocols)
        defer { socket.resume() }
        var continuation: AsyncStream<WebSocketState>.Continuation!
        let stream = AsyncStream<WebSocketState> {
            $0.onTermination = { _ in
                socket.cancel()
                Task { await self.removeDependencies(id: id) }
            }
            continuation = $0
        }
        continuation.yield(.connecting)
        delegate.continuation = continuation
        self.dependencies[id] = (socket, delegate)
        return stream
    }
    
    func close(
        id: ID, with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?
    ) async throws {
        defer { self.dependencies[id] = nil }
        let socket = try self.socket(id: id)
        if let delegate = socket.delegate as? Delegate {
            delegate.continuation?.yield(.closing)
        }
        socket.cancel(with: closeCode, reason: reason)
    }
    
    func receive(id: ID) throws -> AsyncStream<TaskResult<Message>> {
        let socket = try self.socket(id: id)
        return AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    continuation.yield(await TaskResult { try await Message(socket.receive()) })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    
    func send(id: ID, message: URLSessionWebSocketTask.Message) async throws {
        try await self.socket(id: id).send(message)
    }
    
    func sendPing(id: ID) async throws {
        let socket = try self.socket(id: id)
        return try await withCheckedThrowingContinuation { continuation in
            socket.sendPing { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

private extension WebSocketActor {
    func socket(id: ID) throws -> URLSessionWebSocketTask {
        guard let dependencies = self.dependencies[id]?.socket else {
            struct Closed: Error {}
            throw Closed()
        }
        return dependencies
    }
    
    func removeDependencies(id: ID) {
        self.dependencies[id] = nil
    }
}
