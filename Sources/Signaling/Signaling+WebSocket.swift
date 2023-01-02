//
//  File.swift
//  
//
//  Created by Alexander Cyon on 2023-01-01.
//

import Foundation
import AsyncExtensions
import RTCModels

extension URL: Sendable {}


// MARK: WebSocketActor
actor WebSocketActor {
    var task: Task<Void, Never>?
    let webSocketTask: URLSessionWebSocketTask
    
    let readyStateUpdates: AsyncStream<WebSocketState>
    
    let incomingMessageAsyncStream: AsyncStream<URLSessionWebSocketTask.Message>
    let incomingMessageAsyncContinuation: AsyncStream<URLSessionWebSocketTask.Message>.Continuation
    
    private let delegate: WSDelegate
    
    init(
        url: URL
    ) {
        let webSocketTask = URLSession.shared.webSocketTask(with: url)
        let (readyStateUpdates, statusAsyncContinuation) = AsyncStream.streamWithContinuation(WebSocketState.self)
        self.delegate = .init(taskIdentifier: webSocketTask.taskIdentifier, statusAsyncContinuation: statusAsyncContinuation)
        self.readyStateUpdates = readyStateUpdates
        self.webSocketTask = webSocketTask
        (incomingMessageAsyncStream, incomingMessageAsyncContinuation) = AsyncStream.streamWithContinuation(URLSessionWebSocketTask.Message.self)
        
        Task {
            await connect()
        }
    }
}

// MARK: Private
private extension WebSocketActor {
    func connect() {
        webSocketTask.resume()
        self.task = Task { [unowned self] in
            await withThrowingTaskGroup(of: Void.self) { group in
                _ = group.addTaskUnlessCancelled {
                    await self.ping()
                }
                _ = group.addTaskUnlessCancelled {
                    await self.receive()
                }
            }
        }
    }
    
    func ping() {
        webSocketTask.sendPing { maybeError in
            Task { [unowned self] in
                if let error = maybeError {
                    debugPrint("Ping failed, closing due to error: \(String(describing: error))")
                    await self._close(code: .abnormalClosure)
                } else {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 sec
                    try Task.checkCancellation()
                    await self.ping()
                }
            }
        }
    }
    
    func receive() {
        webSocketTask.receive { result in
            Task { [unowned self] in
                switch result {
                case let .failure(error):
                    debugPrint("Receive failed, closing due to error: \(String(describing: error))")
                    self._close(code: .abnormalClosure)
                case let .success(message):
                    self.incomingMessageAsyncContinuation.yield(message)
                    self.receive()
                }
            }
        }
    }
    
    func _close(code: URLSessionWebSocketTask.CloseCode) {
        task?.cancel()
        webSocketTask.cancel(with: code, reason: nil)
        task = nil
    }
}

// MARK: WSDelegate
private extension WebSocketActor {
    final class WSDelegate: NSObject, URLSessionWebSocketDelegate {
        fileprivate let statusAsyncContinuation: AsyncStream<WebSocketState>.Continuation
        private let taskIdentifier: Int
        init(taskIdentifier: Int, statusAsyncContinuation: AsyncStream<WebSocketState>.Continuation) {
            self.taskIdentifier = taskIdentifier
            self.statusAsyncContinuation = statusAsyncContinuation
            super.init()
        }
    }
}


extension URLSessionWebSocketTask.CloseCode {
    func swiftify() -> WebSocketCloseCode {
        switch self {
        case .abnormalClosure:
            return .abnormalClosure
        case .invalid:
            return .invalid
        case .normalClosure:
            return .normalClosure
        case .goingAway:
            return .goingAway
        case .protocolError:
            return .protocolError
        case .unsupportedData:
            return .unsupportedData
        case .noStatusReceived:
            return .noStatusReceived
        case .invalidFramePayloadData:
            return .invalidFramePayloadData
        case .policyViolation:
            return .policyViolation
        case .messageTooBig:
            return .messageTooBig
        case .mandatoryExtensionMissing:
            return .mandatoryExtensionMissing
        case .internalServerError:
            return .internalServerError
        case .tlsHandshakeFailure:
            return .tlsHandshakeFailure
        @unknown default:
            fatalError("unknown unsupported WebSocketCloseCode: \(String(describing: self))")
        }
    }
}

extension WebSocketActor.WSDelegate {
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        guard task.taskIdentifier == taskIdentifier else { return }
        statusAsyncContinuation.yield(.connecting)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard webSocketTask.taskIdentifier == taskIdentifier else { return }
        statusAsyncContinuation.yield(.connected)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard webSocketTask.taskIdentifier == taskIdentifier else { return }
        let reason = closeCode.swiftify()
        statusAsyncContinuation.yield(.closed(reason))
    }
}

// MARK: Internal
internal extension WebSocketActor {
    func close() {
        _close(code: .goingAway)
    }
    
    func send(data: Data) async throws {
        try await webSocketTask.send(.data(data))
    }
}

// MARK: SignalingClient.Transport
public extension SignalingClient.Transport where ID == URL, ReadyState == WebSocketState, OutgoingMessage == Data, IncomingMessage == Data {
    
    static func webSocket(url: URL) -> Self {
        let wsActor = WebSocketActor(url: url)
        return Self.multicast(
            getID: url,
            readyStateAsyncSequence: {
                wsActor.readyStateUpdates
            },
            incomingMessagesAsyncSequence: {
                wsActor.incomingMessageAsyncStream.compactMap {
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
